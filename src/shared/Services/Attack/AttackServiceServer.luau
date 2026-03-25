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
local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local AttackCalculator = require(ReplicatedStorage.Modules.Combat.AttackCalculator)
local WeaponModule = require(ReplicatedStorage.Classes.Weapon.Weapon)

local AttackServiceServer = {}

type AttackProfile = WeaponModule.AttackProfile
type AttackContext = {
	SwingRange: number,
	MaxDashRange: number,
}
type ActiveAttack = {
	Id: string,
	Profile: AttackProfile,
	Weapon: any,
	OriginCFrame: CFrame,
	AttackContext: AttackContext,
	ActiveFrom: number,
	ActiveUntil: number,
	ClearAt: number,
	Hits: { [string]: number },
}

local ActiveAttacks: { [Player]: ActiveAttack } = {}
local NextAttackAt: { [Player]: number } = {}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.MaxParts = 64

local function GetAttackContext(weapon: any): AttackContext
	local context = weapon and weapon:GetAttackContext() or {}
	return {
		SwingRange = context.SwingRange or 4.5,
		MaxDashRange = context.MaxDashRange or 2.5,
	}
end

local function ClearAttackLater(player: Player, attackId: string, clearAt: number, animationId: string)
	local delayTime = math.max(0, clearAt - workspace:GetServerTimeNow())
	task.delay(delayTime, function()
		local active = ActiveAttacks[player]
		if not active or active.Id ~= attackId then
			return
		end

		ActiveAttacks[player] = nil

		if animationId ~= "" then
			AnimationServiceServer.StopPlayer(player, animationId)
		end
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

local function IsTargetInsideCapturedAttack(entity, target, active: ActiveAttack): boolean
	if IsTargetInsideHitbox(entity, target, active.Profile, entity.RootPart.CFrame) then
		return true
	end

	local origin = active.OriginCFrame
	local targetRoot = target.RootPart
	local targetPos = targetRoot.Position
	local flatTarget = Vector3.new(targetPos.X, origin.Position.Y, targetPos.Z)
	local delta = flatTarget - origin.Position
	local distanceToTarget = delta.Magnitude
	local lungeDistance = math.min(active.AttackContext.MaxDashRange, math.max(0, distanceToTarget - active.AttackContext.SwingRange))
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

function AttackServiceServer.ProcessEnemyHit(attacker, target, baseDamage: number, swingRange: number?)
	if not attacker or not target then
		return false
	end

	local profile = GetEnemyAttackProfile(attacker, swingRange)
	if not IsTargetInsideHitbox(attacker, target, profile, attacker.RootPart.CFrame) then
		return false
	end

	print(("Enemy hitbox registered hit: %s -> %s"):format(attacker.Name, target.Name))
	AttackCalculator.Calculate(attacker, target, baseDamage)
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

	local profile = weapon:GetAttackProfile()
	local attackContext = GetAttackContext(weapon)
	local animationId = entity.__Animations["Attack"] or profile.AnimationId
	local attackId = HttpService:GenerateGUID(false)
	local activeFrom = now + profile.Windup
	local activeUntil = activeFrom + profile.ActiveDuration
	local clearAt = activeUntil + profile.Recovery

	NextAttackAt[player] = now + profile.Cooldown
	ActiveAttacks[player] = {
		Id = attackId,
		Profile = profile,
		Weapon = weapon,
		OriginCFrame = entity.RootPart.CFrame,
		AttackContext = attackContext,
		ActiveFrom = activeFrom,
		ActiveUntil = activeUntil,
		ClearAt = clearAt,
		Hits = {},
	}

	if animationId ~= "" then
		AnimationServiceServer.PlayPlayer(player, animationId)
	end

	API:FireClient(player, "AttackStarted", {
		AttackId = attackId,
		ActiveFrom = activeFrom,
		ActiveUntil = activeUntil,
		ClearAt = clearAt,
		Profile = profile,
	})

	ClearAttackLater(player, attackId, clearAt, animationId)
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
	if now < active.ActiveFrom or now > active.ActiveUntil then
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

	local lastHitAt = active.Hits[payload.TargetUUID]
	if lastHitAt and now - lastHitAt < active.Profile.HitReset then
		return
	end

	if not IsTargetInsideCapturedAttack(entity, target, active) then
		return
	end

	print(("Hitbox registered hit: %s -> %s"):format(player.Name, target.Name))
	active.Hits[payload.TargetUUID] = now
	entity:ApplyDamage(active.Weapon:GetDamage(entity), target)
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "RequestPrimaryAttack" then
		BeginPrimaryAttack(player)
	elseif action == "ReportHit" then
		ReportHit(player, payload)
	end
end)

return table.freeze(AttackServiceServer)
