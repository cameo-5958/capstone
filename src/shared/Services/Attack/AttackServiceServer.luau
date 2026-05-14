--!strict

local endpoint = script.Parent:FindFirstChild("AttackEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "AttackEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationServiceServer = require(ReplicatedStorage.Services.Animation.AnimationServiceServer)
local Damage = require(ReplicatedStorage.Classes.Attack.Damage)
local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local ProjectileServiceServer = require(ReplicatedStorage.Services.Projectile.ProjectileServiceServer)
local WeaponTypes = require(ReplicatedStorage.Classes.Weapon.WeaponTypes)
local ClassCombos = require(ReplicatedStorage.Database.Weapons.Default.Combos)

local AttackServiceServer = {}

type AttackProfile = WeaponTypes.AttackProfile
type AnimationId = WeaponTypes.AnimationId
type ComboAttack = WeaponTypes.ComboAttack
type ComboAttackContext = WeaponTypes.ComboAttackContext
type ComboAttackProfile = WeaponTypes.ComboAttackProfile
type HitWindow = WeaponTypes.HitWindow
type ComboDefinition = WeaponTypes.ComboDefinition
type ComboSet = WeaponTypes.ComboSet
type AttackContext = ComboAttackContext
type ActiveHitWindow = {
	Index: number,
	ActiveFrom: number,
	ActiveUntil: number,
	AttackContext: AttackContext,
	Profile: AttackProfile,
}
type ActiveAttack = {
	Id: string,
	Profile: AttackProfile,
	Weapon: any,
	ComboBaseDamage: number,
	IsHeavy: boolean,
	DoesKnockback: boolean,
	NoStamina: boolean,
	StopAnimationOnClear: boolean,
	OriginCFrame: CFrame,
	AttackContext: AttackContext,
	HitWindows: { ActiveHitWindow },
	ClearAt: number,
	Hits: { [number]: { [string]: number } },
}

local ActiveAttacks: { [Player]: ActiveAttack } = {}
local NextAttackAt: { [Player]: number } = {}
local HIT_CONFIRM_RETRY_DELAY = 0.08
local DEFAULT_BOW_GRAVITY_SCALE = 0.35
local DEFAULT_BOW_HOMING_STRENGTH = 12
local DEFAULT_BOW_SHOT_LOCK_DURATION = 0.65
local BOW_SHOT_LOCK_TOKEN_ATTRIBUTE = "BowShotLockToken"
local BOW_SHOT_ANIMATIONS = {
	"rbxassetid://135215634088644",
	"rbxassetid://127584242031977",
	"rbxassetid://117890025835582",
}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.MaxParts = 64

local function ResolveAnimationId(animationId: AnimationId): string
	if type(animationId) == "string" then
		return animationId
	end

	local count = #animationId
	if count == 0 then
		return ""
	end

	local chosen = animationId[math.random(1, count)]
	return type(chosen) == "string" and chosen or ""
end

local function HasAnimationId(animationId: AnimationId?): boolean
	if animationId == nil then
		return false
	end

	if type(animationId) == "string" then
		return animationId ~= ""
	end

	return #animationId > 0
end

local function GetAttackContext(weapon: any): AttackContext
	local context = weapon and weapon:GetAttackContext() or {}
	return {
		SightRange = context.SightRange or 32,
		SwingRange = context.SwingRange or 4.5,
		MaxDashRange = context.MaxDashRange or 2.5,
		LungeDuration = context.LungeDuration or 0.08,
		LockDuration = context.LockDuration or 0.35,
		MovementLockDuration = context.MovementLockDuration,
		ActionLockDuration = context.ActionLockDuration,
		ManaCost = context.ManaCost,
		StaminaCost = context.StaminaCost,
		Range = context.Range,
	}
end

local function MergeAttackContext(baseContext: AttackContext?, overrideContext: ComboAttackContext?): AttackContext
	local merged = table.clone(baseContext or {})
	if overrideContext then
		for key, value in pairs(overrideContext) do
			merged[key] = value
		end
	end
	return merged
end

local function MergeAttackProfile(baseProfile: AttackProfile, overrideProfile: ComboAttackProfile?): AttackProfile
	local merged = table.clone(baseProfile)
	local mergedAny = merged :: any
	if overrideProfile then
		for key, value in pairs(overrideProfile) do
			mergedAny[key] = value
		end
	end
	return merged
end

local function GetNearestBowTarget(entity, acquireRange: number?): any?
	return EnemyServiceServer.GetClosest(entity.RootPart.Position, acquireRange or 96)
end

local function ChooseBowShotAnimation(): string
	return BOW_SHOT_ANIMATIONS[math.random(1, #BOW_SHOT_ANIMATIONS)]
end

local function LockBowShooter(entity, duration: number)
	local character = entity.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local lockToken = (character:GetAttribute(BOW_SHOT_LOCK_TOKEN_ATTRIBUTE) or 0) + 1
	character:SetAttribute(BOW_SHOT_LOCK_TOKEN_ATTRIBUTE, lockToken)

	humanoid.WalkSpeed = 0
	humanoid:Move(Vector3.zero, false)
	entity.RootPart.AssemblyLinearVelocity = Vector3.zero

	task.delay(duration, function()
		if character.Parent == nil then
			return
		end

		if character:GetAttribute(BOW_SHOT_LOCK_TOKEN_ATTRIBUTE) ~= lockToken then
			return
		end

		humanoid.WalkSpeed = entity:GetStat("Speed")
	end)
end

local function BeginBowCharge(player: Player)
	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity:IsAlive() then
		return
	end

	local weapon = entity:GetEquippedWeapon()
	if not weapon or weapon.Class ~= "Bow" then
		return
	end
end

local function ReleaseBowCharge(player: Player, payload: { [string]: any }?)
	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity:IsAlive() then
		return
	end

	local weapon = entity:GetEquippedWeapon()
	if not weapon or weapon.Class ~= "Bow" then
		return
	end

	local attackContext = weapon:GetAttackContext()
	local lockDuration =
		attackContext.MovementLockDuration or attackContext.LockDuration or DEFAULT_BOW_SHOT_LOCK_DURATION
	AnimationServiceServer.PlayPlayerOnce(player, ChooseBowShotAnimation())
	LockBowShooter(entity, lockDuration)
	local origin = entity.RootPart.Position + Vector3.new(0, attackContext.ProjectileSpawnHeight or 2.25, 0)
	local target = GetNearestBowTarget(entity, attackContext.AcquireRange)
	local direction = entity.RootPart.CFrame.LookVector
	local speed = attackContext.ProjectileSpeed or 110
	if target then
		local targetPosition = target.RootPart.Position + Vector3.new(0, attackContext.ProjectileAimHeight or 1.5, 0)
		local delta = targetPosition - origin
		if delta.Magnitude > 0.001 then
			direction = delta.Unit
		end
	end

	ProjectileServiceServer.FireArrow({
		Position = origin,
		Velocity = direction * speed,
		Speed = speed,
		MaxDistance = (attackContext.Range or 60) * entity:GetStat("ArrowTravelDistance"),
		GravityScale = attackContext.GravityScale or DEFAULT_BOW_GRAVITY_SCALE,
		Radius = attackContext.ProjectileRadius or 0.5,
		DamageScale = 1,
		Owner = entity,
		Weapon = weapon,
		Target = target,
		HomingStrength = attackContext.HomingStrength or DEFAULT_BOW_HOMING_STRENGTH,
	})
end

local function ClearAttackLater(player: Player, attackId: string, clearAt: number)
	local delayTime = math.max(0, clearAt - workspace:GetServerTimeNow())
	task.delay(delayTime, function()
		local active = ActiveAttacks[player]
		if not active or active.Id ~= attackId then
			return
		end

		ActiveAttacks[player] = nil
	end)
end

local function GetHitboxCFrame(rootCFrame: CFrame, profile: AttackProfile): CFrame
	return rootCFrame * profile.HitboxOffset
end

local function IsTargetInsideHitbox(entity, target, profile: AttackProfile, rootCFrame: CFrame): boolean
	overlapParams.FilterDescendantsInstances = { entity.Character }
	local parts = workspace:GetPartBoundsInBox(GetHitboxCFrame(rootCFrame, profile), profile.HitboxSize, overlapParams)
	for _, part in ipairs(parts) do
		if part:IsDescendantOf(target.Character) then
			return true
		end
	end

	return false
end

local function IsTargetInsideCapturedAttack(entity, target, active: ActiveAttack, attackContext: AttackContext): boolean
	if IsTargetInsideHitbox(entity, target, active.Profile, entity.RootPart.CFrame) then
		return true
	end

	local origin = active.OriginCFrame
	local targetRoot = target.RootPart
	local targetPos = targetRoot.Position
	local flatTarget = Vector3.new(targetPos.X, origin.Position.Y, targetPos.Z)
	local delta = flatTarget - origin.Position
	local distanceToTarget = delta.Magnitude
	local lungeDistance =
		math.min(attackContext.MaxDashRange or 2.5, math.max(0, distanceToTarget - (attackContext.SwingRange or 4.5)))
	local endPosition = origin.Position + origin.LookVector * lungeDistance
	local endCFrame = CFrame.lookAt(endPosition, endPosition + origin.LookVector)

	return IsTargetInsideHitbox(entity, target, active.Profile, endCFrame)
end

local function GetEnemyAttackProfile(attacker, swingRange: number?): AttackProfile
	local weapon = attacker:GetEquippedWeapon()
	if weapon then
		return weapon:GetAttackProfile()
	end

	local effectiveSwingRange = swingRange or 4.5
	local hitRange = effectiveSwingRange + 1.5
	return {
		AnimationId = "",
		Windup = 0,
		ActiveDuration = 0.1,
		Recovery = 0,
		Cooldown = 0,
		HitReset = 0,
		HitboxSize = Vector3.new(3.25, 4.5, hitRange),
		HitboxOffset = CFrame.new(0, 0, -(hitRange * 0.5)),
	}
end

local function IsComboWeapon(weapon): boolean
	return weapon.Class == "Sword" or weapon.Class == "Claymore" or weapon.Class == "Spear"
end

local function GetDefaultCombo(comboSet: ComboSet): ComboDefinition?
	if comboSet.DefaultCombo and comboSet.Combos[comboSet.DefaultCombo] then
		return comboSet.Combos[comboSet.DefaultCombo]
	end

	for _, combo in pairs(comboSet.Combos) do
		return combo
	end

	return nil
end

local function BuildActiveHitWindows(
	now: number,
	profile: AttackProfile,
	baseAttackContext: AttackContext,
	comboAttack: ComboAttack?
): { ActiveHitWindow }
	local configuredWindows = comboAttack and comboAttack.HitWindows
	local comboAttackContext = MergeAttackContext(baseAttackContext, comboAttack and comboAttack.AttackContext)
	local comboAttackProfile = MergeAttackProfile(profile, comboAttack and comboAttack.AttackProfile)
	local activeHitWindows = {}

	if configuredWindows and #configuredWindows > 0 then
		for index, window in ipairs(configuredWindows) do
			local delay = math.max(0, window.Delay or 0)
			local windowProfile = MergeAttackProfile(comboAttackProfile, window.AttackProfile)
			local duration = math.max(0, window.Duration or windowProfile.ActiveDuration)
			table.insert(activeHitWindows, {
				Index = index,
				ActiveFrom = now + delay,
				ActiveUntil = now + delay + duration,
				AttackContext = MergeAttackContext(comboAttackContext, window.AttackContext),
				Profile = windowProfile,
			})
		end
	else
		table.insert(activeHitWindows, {
			Index = 1,
			ActiveFrom = now + comboAttackProfile.Windup,
			ActiveUntil = now + comboAttackProfile.Windup + comboAttackProfile.ActiveDuration,
			AttackContext = comboAttackContext,
			Profile = comboAttackProfile,
		})
	end

	return activeHitWindows
end

local function GetHitWindowAtTime(active: ActiveAttack, now: number): ActiveHitWindow?
	for _, hitWindow in ipairs(active.HitWindows) do
		if now >= hitWindow.ActiveFrom and now <= hitWindow.ActiveUntil then
			return hitWindow
		end
	end

	return nil
end

local function ResolveComboAttack(entity, weapon, now: number): (ComboAttack?, boolean, boolean)
	if not IsComboWeapon(weapon) then
		entity:ResetComboState()
		return nil, true, false
	end

	local comboSet = ClassCombos[weapon.Class] :: ComboSet?
	if not comboSet then
		entity:ResetComboState()
		return nil, true, false
	end

	local combo = GetDefaultCombo(comboSet)
	if not combo or #combo.Attacks == 0 then
		entity:ResetComboState()
		return nil, true, false
	end

	local state = entity.__Components.ComboState
	local attackIndex = state.AttackIndex
	local expired = now - state.LastAttackAt > comboSet.ExpireAfter
	local startedNewSequence = false
	if state.WeaponClass ~= weapon.Class or state.ComboId ~= combo.Id or expired then
		attackIndex = 1
		startedNewSequence = true
	end
	if attackIndex == 1 then
		startedNewSequence = true
	end

	local attack = combo.Attacks[math.clamp(attackIndex, 1, #combo.Attacks)]
	state.WeaponClass = weapon.Class
	state.ComboId = combo.Id
	state.LastAttackAt = now
	state.AttackIndex = (attackIndex % #combo.Attacks) + 1

	return attack, attackIndex < #combo.Attacks, startedNewSequence
end

function AttackServiceServer.ProcessEnemyHit(attacker, target, physicalAttack: number, swingRange: number?)
	if not attacker or not target then
		return false
	end

	if target:IsInvincible() then
		print(("Hit whiffed on invincible target: %s -> %s"):format(attacker.Name, target.Name))
		return false
	end

	local profile = GetEnemyAttackProfile(attacker, swingRange)
	if not IsTargetInsideHitbox(attacker, target, profile, attacker.RootPart.CFrame) then
		return false
	end

	Damage.DirectDamageToEntity(attacker, target, physicalAttack)
	return true
end

local function BeginPrimaryAttack(player: Player)
	local now = workspace:GetServerTimeNow()
	if now < (NextAttackAt[player] or 0) then
		return
	end

	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity:IsAlive() then
		return
	end

	local weapon = entity:GetEquippedWeapon()
	if not weapon then
		return
	end

	local comboAttack, stopAnimationOnClear, startedNewSequence = ResolveComboAttack(entity, weapon, now)
	local profile = MergeAttackProfile(weapon:GetAttackProfile(), comboAttack and comboAttack.AttackProfile)
	local attackContext = GetAttackContext(weapon)
	local powerScale = if comboAttack then comboAttack.PowerScale else 1
	local isHeavy = comboAttack ~= nil and comboAttack.IsHeavy == true
	local doesKnockback = comboAttack ~= nil and comboAttack.DoesKnockback == true
	local noStamina = comboAttack ~= nil and comboAttack.NoStamina == true
	if not PlayerServiceServer.CanStartPrimaryAttack(player, isHeavy, noStamina) then
		return
	end

	local animationSource = if comboAttack and HasAnimationId(comboAttack.AnimationId)
		then comboAttack.AnimationId
		elseif
			entity.__Animations["Attack"] ~= nil and entity.__Animations["Attack"] ~= ""
		then entity.__Animations["Attack"]
		else profile.AnimationId
	local animationId = ResolveAnimationId(animationSource)
	local attackId = HttpService:GenerateGUID(false)
	local hitWindows = BuildActiveHitWindows(now, profile, attackContext, comboAttack)
	local lastHitWindow = hitWindows[#hitWindows]
	local clearAt = (lastHitWindow and lastHitWindow.ActiveUntil or now) + profile.Recovery
	if not PlayerServiceServer.RegisterPrimaryAttack(player, clearAt, isHeavy, noStamina) then
		return
	end

	NextAttackAt[player] = now + profile.Cooldown
	ActiveAttacks[player] = {
		Id = attackId,
		Profile = profile,
		Weapon = weapon,
		ComboBaseDamage = powerScale,
		IsHeavy = isHeavy,
		DoesKnockback = doesKnockback,
		NoStamina = noStamina,
		StopAnimationOnClear = stopAnimationOnClear,
		OriginCFrame = entity.RootPart.CFrame,
		AttackContext = attackContext,
		HitWindows = hitWindows,
		ClearAt = clearAt,
		Hits = {},
	}

	if animationId ~= "" then
		AnimationServiceServer.PlayPlayerOnce(player, animationId)
	end

	API:FireClient(player, "AttackStarted", {
		AttackId = attackId,
		HitWindows = hitWindows,
		ClearAt = clearAt,
		Profile = profile,
	})

	ClearAttackLater(player, attackId, clearAt)
end

local function ReportHit(player: Player, payload: { [string]: any }?)
	if not payload then
		return
	end

	local active = ActiveAttacks[player]
	if not active or active.Id ~= payload.AttackId then
		return
	end

	local now = workspace:GetServerTimeNow()
	local hitWindow = GetHitWindowAtTime(active, now)
	if not hitWindow then
		return
	end

	local hitWindowIndex = payload.HitWindowIndex
	if typeof(hitWindowIndex) ~= "number" or hitWindowIndex ~= hitWindow.Index then
		return
	end

	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity:IsAlive() then
		return
	end

	local target = EnemyServiceServer.GetByUUID(payload.TargetUUID)
	if not target or not target:IsAlive() then
		return
	end

	if target:IsInvincible() then
		print(("Hit whiffed on invincible target: %s -> %s"):format(player.Name, target.Name))
		return
	end

	active.Hits[hitWindowIndex] = active.Hits[hitWindowIndex] or {}
	local hitWindowHits = active.Hits[hitWindowIndex]
	if hitWindowHits[payload.TargetUUID] then
		return
	end

	if not IsTargetInsideCapturedAttack(entity, target, active, hitWindow.AttackContext) then
		local attackId = active.Id
		local targetUUID = payload.TargetUUID
		task.delay(HIT_CONFIRM_RETRY_DELAY, function()
			local retryActive = ActiveAttacks[player]
			if not retryActive or retryActive.Id ~= attackId then
				return
			end

			local retryEntity = PlayerServiceServer.GetEntity(player)
			if not retryEntity or not retryEntity:IsAlive() then
				return
			end

			local retryTarget = EnemyServiceServer.GetByUUID(targetUUID)
			if not retryTarget or not retryTarget:IsAlive() or retryTarget:IsInvincible() then
				return
			end

			local retryNow = workspace:GetServerTimeNow()
			local retryWindow = GetHitWindowAtTime(retryActive, retryNow)
			if not retryWindow or retryWindow.Index ~= hitWindowIndex then
				return
			end

			retryActive.Hits[hitWindowIndex] = retryActive.Hits[hitWindowIndex] or {}
			local retryWindowHits = retryActive.Hits[hitWindowIndex]
			if retryWindowHits[targetUUID] then
				return
			end

			if not IsTargetInsideCapturedAttack(retryEntity, retryTarget, retryActive, retryWindow.AttackContext) then
				return
			end

			retryWindowHits[targetUUID] = retryNow
			retryActive.Weapon:ExecuteAttack(retryTarget, retryActive.ComboBaseDamage, retryEntity, {
				IsHeavy = retryActive.IsHeavy,
				DoesKnockback = retryActive.DoesKnockback,
				AttackContext = retryWindow.AttackContext,
			})
		end)
		return
	end

	print(("[AttackService] Hitbox registered hit: %s -> %s"):format(player.Name, target.Name))
	hitWindowHits[payload.TargetUUID] = now
	active.Weapon:ExecuteAttack(target, active.ComboBaseDamage, entity, {
		IsHeavy = active.IsHeavy,
		DoesKnockback = active.DoesKnockback,
		AttackContext = hitWindow.AttackContext,
	})
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "RequestPrimaryAttack" then
		BeginPrimaryAttack(player)
	elseif action == "BeginBowCharge" then
		BeginBowCharge(player)
	elseif action == "ReleaseBowCharge" then
		ReleaseBowCharge(player, payload)
	elseif action == "ReportHit" then
		ReportHit(player, payload)
	end
end)

return table.freeze(AttackServiceServer)
