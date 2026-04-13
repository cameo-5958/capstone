--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AnimationServiceClient = require(ReplicatedStorage.Services.Animation.AnimationServiceClient)
local EnemyServiceClient = require(ReplicatedStorage.Services.Enemy.EnemyServiceClient)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local MovementShared = require(script.Parent.MovementShared)
local ClassCombos = require(ReplicatedStorage.Database.Weapons.Default.Combos)
local PlayerConfig = require(ReplicatedStorage.Database.Players.Default.Data)
local EntityTypes = require(script.Parent.EntityTypes)
type Entity = EntityTypes.Entity

type SharedMovementEngine = MovementShared.SharedMovementEngine

local MovementEngine = {}
MovementEngine.__index = MovementEngine
setmetatable(MovementEngine, { __index = MovementShared })

local DEFAULT_ATTACK_MOVEMENT_LOCK_DURATION = 1.2
local ACTION_CANCEL_LEAD_TIME = 0.5

export type MovementEngine = SharedMovementEngine & {
	Character: Model,
	Humanoid: Humanoid,
	RootPart: Part,
	Speed: number,
	EntityUUID: number?,
	Player: Player?,
	WalkAnimationPlaying: boolean,
	IdleAnimationPlaying: boolean,
	CurrentLocomotionAnimation: string?,
	CurrentLocomotionAnimationId: string?,
	LocomotionResumeToken: number,
	CurrentActionAnimationIds: { string },
	__Animations: { string: string },
	__ComboState: {
		WeaponClass: string?,
		ComboId: string?,
		AttackIndex: number,
		LastAttackAt: number,
	},
	GetTarget: (MovementEngine, Vector3, number) -> Entity,
	GetAnimation: (MovementEngine, string) -> string,
	Play: (MovementEngine, string) -> (),
	Stop: (MovementEngine, string) -> (),
	UpdateFacingFromCamera: (MovementEngine) -> (),
	UpdateMovementAnimation: (MovementEngine) -> (),
	DisableAllMovement: (MovementEngine) -> (),
	EnableAllMovement: (MovementEngine) -> (),
	Attack: (MovementEngine) -> boolean,
	Dash: (MovementEngine) -> boolean,
	new: (Entity) -> (),
	lnew: (Player) -> (),
	init: (MovementEngine) -> (),
}

function MovementEngine.__tostring(self: MovementEngine): string
	return "MovementEngine<" .. (self.EntityUUID or self.Character.Name) .. ">"
end

function MovementEngine.init(self: MovementEngine): ()
	self.AllMovementDisabled = false
	self.WalkAnimationPlaying = false
	self.IdleAnimationPlaying = false
	self.CurrentLocomotionAnimation = nil
	self.CurrentLocomotionAnimationId = nil
	self.LocomotionResumeToken = 0
	self.CurrentActionAnimationIds = {}
	self.__ComboState = {
		WeaponClass = nil,
		ComboId = nil,
		AttackIndex = 1,
		LastAttackAt = 0,
	}
	MovementShared.Init(self)
end

local function IsComboWeapon(weaponClass: string?): boolean
	return weaponClass == "Sword" or weaponClass == "Claymore" or weaponClass == "Spear"
end

local function GetDefaultCombo(comboSet): any
	if comboSet.DefaultCombo and comboSet.Combos[comboSet.DefaultCombo] then
		return comboSet.Combos[comboSet.DefaultCombo]
	end

	for _, combo in pairs(comboSet.Combos) do
		return combo
	end

	return nil
end

local function GetMovementLockDuration(
	self: MovementEngine,
	equippedWeapon: { [string]: any }?,
	fallbackDuration: number
): number
	if not equippedWeapon or not IsComboWeapon(equippedWeapon.Class) then
		self.__ComboState.WeaponClass = nil
		self.__ComboState.ComboId = nil
		self.__ComboState.AttackIndex = 1
		self.__ComboState.LastAttackAt = 0
		return fallbackDuration
	end

	local comboSet = ClassCombos[equippedWeapon.Class]
	if not comboSet then
		return fallbackDuration
	end

	local combo = GetDefaultCombo(comboSet)
	if not combo or #combo.Attacks == 0 then
		return fallbackDuration
	end

	local now = workspace:GetServerTimeNow()
	local state = self.__ComboState
	local attackIndex = state.AttackIndex
	local expired = now - state.LastAttackAt > comboSet.ExpireAfter
	if state.WeaponClass ~= equippedWeapon.Class or state.ComboId ~= combo.Id or expired then
		attackIndex = 1
	end

	local attack = combo.Attacks[math.clamp(attackIndex, 1, #combo.Attacks)]
	state.WeaponClass = equippedWeapon.Class
	state.ComboId = combo.Id
	state.AttackIndex = (attackIndex % #combo.Attacks) + 1
	state.LastAttackAt = now

	return attack.MovementLockedUntil or fallbackDuration
end

local function GetDefaultAttackContext(): { [string]: any }
	return {
		SightRange = 32,
		SwingRange = 4.5,
		MaxDashRange = 2.5,
		LungeDuration = 0.08,
		LockDuration = 0.35,
	}
end

local function MergeAttackContext(baseContext: { [string]: any }?, overrideContext: { [string]: any }?): { [string]: any }
	local merged = table.clone(baseContext or {})
	if overrideContext then
		for key, value in pairs(overrideContext) do
			merged[key] = value
		end
	end
	return merged
end

local function GetAttackLockDurations(
	self: MovementEngine,
	equippedWeapon: { [string]: any }?,
	_attackContext: { [string]: any }
): (number, number)
	local movementLockDuration = GetMovementLockDuration(self, equippedWeapon, DEFAULT_ATTACK_MOVEMENT_LOCK_DURATION)
	local actionLockDuration = math.max(0, movementLockDuration - ACTION_CANCEL_LEAD_TIME)
	return movementLockDuration, actionLockDuration
end

local function GetResolvedComboAttackContext(
	equippedWeapon: { [string]: any }?,
	comboAttack: { [string]: any }?
): { [string]: any }
	local resolvedContext = MergeAttackContext(GetDefaultAttackContext(), equippedWeapon and equippedWeapon.AttackContext or nil)
	if comboAttack == nil then
		return resolvedContext
	end

	resolvedContext = MergeAttackContext(resolvedContext, comboAttack.AttackContext)
	local hitWindows = comboAttack.HitWindows
	if hitWindows and #hitWindows > 0 then
		resolvedContext = MergeAttackContext(resolvedContext, hitWindows[1].AttackContext)
	end

	return resolvedContext
end

local function PeekNextComboAttack(self: MovementEngine, equippedWeapon: { [string]: any }?): any
	if not equippedWeapon or not IsComboWeapon(equippedWeapon.Class) then
		return nil
	end

	local comboSet = ClassCombos[equippedWeapon.Class]
	if not comboSet then
		return nil
	end

	local combo = GetDefaultCombo(comboSet)
	if not combo or #combo.Attacks == 0 then
		return nil
	end

	local now = workspace:GetServerTimeNow()
	local state = self.__ComboState
	local attackIndex = state.AttackIndex
	local expired = now - state.LastAttackAt > comboSet.ExpireAfter
	if state.WeaponClass ~= equippedWeapon.Class or state.ComboId ~= combo.Id or expired then
		attackIndex = 1
	end

	return combo.Attacks[math.clamp(attackIndex, 1, #combo.Attacks)]
end

local function CollectComboAnimationIds(weaponClass: string?): { string }
	if not weaponClass then
		return {}
	end

	local comboSet = ClassCombos[weaponClass]
	if not comboSet then
		return {}
	end

	local animationIds = {}
	local seen = {}
	for _, combo in pairs(comboSet.Combos) do
		for _, attack in ipairs(combo.Attacks) do
			local animationId = attack.AnimationId
			if type(animationId) == "string" then
				if animationId ~= "" and not seen[animationId] then
					seen[animationId] = true
					table.insert(animationIds, animationId)
				end
			else
				for _, candidate in ipairs(animationId) do
					if type(candidate) == "string" and candidate ~= "" and not seen[candidate] then
						seen[candidate] = true
						table.insert(animationIds, candidate)
					end
				end
			end
		end
	end

	return animationIds
end

local function CollectAllComboAnimationIds(): { string }
	local animationIds = {}
	local seen = {}

	for weaponClass in pairs(ClassCombos) do
		for _, animId in ipairs(CollectComboAnimationIds(weaponClass)) do
			if not seen[animId] then
				seen[animId] = true
				table.insert(animationIds, animId)
			end
		end
	end

	return animationIds
end

local AllComboAnimationIds = CollectAllComboAnimationIds()

local function IsActionAnimationPlaying(self: MovementEngine): boolean
	local equippedWeapon = WeaponServiceClient.GetEquippedWeaponData()
	local activeAnimationIds = {}

	if equippedWeapon then
		for _, animId in ipairs(CollectComboAnimationIds(equippedWeapon.Class)) do
			table.insert(activeAnimationIds, animId)
		end
	end

	local dashAnimation = self:GetAnimation("Dash")
	if dashAnimation ~= "" then
		table.insert(activeAnimationIds, dashAnimation)
	end

	local backstepAnimation = self:GetAnimation("Backstep")
	if backstepAnimation ~= "" then
		table.insert(activeAnimationIds, backstepAnimation)
	end

	return AnimationServiceClient.IsAnyLocalAnimationPlaying(activeAnimationIds)
end

local function IsBowEquipped(): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil and character:GetAttribute("ForceFaceCamera") == true
end

local function GetCameraRelativeDashDirection(rootPart: BasePart): (Vector3, boolean)
	local camera = workspace.CurrentCamera
	if not camera then
		return -rootPart.CFrame.LookVector.Unit, false
	end

	local inputX = 0
	local inputZ = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		inputX -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		inputX += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		inputZ += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		inputZ -= 1
	end

	if inputX == 0 and inputZ == 0 then
		return -rootPart.CFrame.LookVector.Unit, false
	end

	local cameraForward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local cameraRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if cameraForward.Magnitude <= 0.001 or cameraRight.Magnitude <= 0.001 then
		return -rootPart.CFrame.LookVector.Unit, false
	end

	local dashDirection = (cameraForward.Unit * inputZ) + (cameraRight.Unit * inputX)
	if dashDirection.Magnitude <= 0.001 then
		return -rootPart.CFrame.LookVector.Unit, false
	end

	return dashDirection.Unit, true
end

local function GetProjectedTargetLocation(target: Entity, leadTime: number): Vector3
	local rootPart = target.RootPart
	local velocity = rootPart.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	return rootPart.Position + flatVelocity * leadTime
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function IsTargetAlive(target: Entity): boolean
	if not target.Character or target.Character.Parent == nil or not target.RootPart then
		return false
	end

	local humanoid = target.Character:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") and humanoid.Health <= 0 then
		return false
	end

	return target:IsAlive()
end

local function HasLineOfSight(self: MovementEngine, target: Entity): boolean
	raycastParams.FilterDescendantsInstances = { self.Character }

	local origin = self.RootPart.Position
	local targetPos = target.RootPart.Position
	local delta = targetPos - origin
	local result = workspace:Raycast(origin, delta, raycastParams)

	if not result then
		return true
	end

	return result.Instance:IsDescendantOf(target.Character)
end

function MovementEngine.lnew(): MovementEngine
	local lp = Players.LocalPlayer
	local chr = lp.Character or lp.CharacterAdded:Wait()
	local self = setmetatable({}, MovementEngine)
	local humanoid = chr:WaitForChild("Humanoid") :: Humanoid

	self.States = {}
	self.Character = chr
	self.Humanoid = humanoid
	self.RootPart = chr.PrimaryPart :: Part
	self.Player = lp
	self.Speed = humanoid:GetAttribute("EntitySpeed") or humanoid.WalkSpeed
	self.__Animations = table.clone(PlayerConfig.__Animations or {});
	((self :: any) :: MovementEngine):init()

	humanoid:GetAttributeChangedSignal("EntitySpeed"):Connect(function()
		local nextSpeed = humanoid:GetAttribute("EntitySpeed")
		if typeof(nextSpeed) ~= "number" then
			return
		end

		self.Speed = nextSpeed
		if self:IsMovementEnabled() then
			self.Humanoid.WalkSpeed = nextSpeed
		end
	end)

	self.Humanoid.Running:Connect(function()
		self:UpdateMovementAnimation()
	end)
	self.Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		self:UpdateMovementAnimation()
	end)
	RunService.RenderStepped:Connect(function()
		self:UpdateFacingFromCamera()
	end)

	return (self :: any) :: MovementEngine
end

function MovementEngine.GetTarget(self: MovementEngine, pos: Vector3, sight: number?): Entity
	local closest: Entity? = nil
	local closestDistance = sight or 64

	for _, enemy in pairs(EnemyServiceClient.GetAll()) do
		if not IsTargetAlive(enemy) then
			continue
		end

		local distance = (enemy.RootPart.Position - pos).Magnitude
		if distance < closestDistance and HasLineOfSight(self, enemy) then
			closest = enemy
			closestDistance = distance
		end
	end

	return closest :: Entity
end

function MovementEngine.UpdateFacingFromCamera(self: MovementEngine)
	local camera = workspace.CurrentCamera
	if not camera or not self.Character or self.Character.Parent == nil then
		return
	end

	if not IsBowEquipped() then
		self.Humanoid.AutoRotate = true
		return
	end

	local lookVector = camera.CFrame.LookVector
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude <= 0.001 then
		return
	end

	self.Humanoid.AutoRotate = false
	local desiredLook = flatLook.Unit
	local currentLook = Vector3.new(self.RootPart.CFrame.LookVector.X, 0, self.RootPart.CFrame.LookVector.Z)
	if currentLook.Magnitude > 0.001 and currentLook.Unit:Dot(desiredLook) > 0.999 then
		return
	end

	self.RootPart.CFrame = CFrame.lookAt(self.RootPart.Position, self.RootPart.Position + desiredLook)
end

function MovementEngine.DisableAllMovement(self: MovementEngine)
	self.AllMovementDisabled = true
	self:DisableMovement()
	self:CancelLinearVelocity()
end

function MovementEngine.EnableAllMovement(self: MovementEngine)
	self.AllMovementDisabled = false
	self:DeferTask()
end

local function StopCurrentLocomotionAnimation(self: MovementEngine)
	if self.CurrentLocomotionAnimationId then
		AnimationServiceClient.StopAnimation(self.CurrentLocomotionAnimationId)
	end

	self.WalkAnimationPlaying = false
	self.IdleAnimationPlaying = false
	self.CurrentLocomotionAnimation = nil
	self.CurrentLocomotionAnimationId = nil
end

local function StopActionAnimations(self: MovementEngine)
	local animationIds = table.clone(AllComboAnimationIds)

	local dashAnimation = self:GetAnimation("Dash")
	if dashAnimation ~= "" then
		table.insert(animationIds, dashAnimation)
	end

	local backstepAnimation = self:GetAnimation("Backstep")
	if backstepAnimation ~= "" then
		table.insert(animationIds, backstepAnimation)
	end

	for _, animationId in ipairs(self.CurrentActionAnimationIds) do
		table.insert(animationIds, animationId)
	end

	AnimationServiceClient.StopAnimation(animationIds)
	self.CurrentActionAnimationIds = {}
end

local function TrackActionAnimation(self: MovementEngine, animationId: string)
	if animationId == "" then
		return
	end

	table.insert(self.CurrentActionAnimationIds, animationId)
end

local function ScheduleLocomotionResume(self: MovementEngine, duration: number): number
	self.LocomotionResumeToken += 1
	local token = self.LocomotionResumeToken

	task.delay(duration, function()
		if self.LocomotionResumeToken ~= token then
			return
		end

		StopActionAnimations(self)
		self:UpdateMovementAnimation()
	end)

	return token
end

function MovementEngine.Attack(self: MovementEngine): boolean
	if not self:IsActionEnabled() then
		return false
	end

	local equippedWeapon = WeaponServiceClient.GetEquippedWeaponData()
	if not equippedWeapon then
		return false
	end

	local comboAttack = PeekNextComboAttack(self, equippedWeapon)
	local attackContext = GetResolvedComboAttackContext(equippedWeapon, comboAttack)
	StopActionAnimations(self)
	StopCurrentLocomotionAnimation(self)

	local attackSightRange = attackContext.SightRange
	local attackSwingRange = attackContext.SwingRange
	local maxLungeDistance = attackContext.MaxDashRange
	local lungeDuration = attackContext.LungeDuration
	local movementLockDuration, actionLockDuration = GetAttackLockDurations(self, equippedWeapon, attackContext)

	local target = self:GetTarget(self.RootPart.Position, attackSightRange)
	local targetLocation = Vector3.zero

	if not target then
		targetLocation = self.RootPart.Position + self.RootPart.CFrame.LookVector.Unit * attackSwingRange
	else
		targetLocation = GetProjectedTargetLocation(target, 0.12)
	end

	self:LockMovement(movementLockDuration)
	self:LockAction(actionLockDuration)
	ScheduleLocomotionResume(self, movementLockDuration)

	local flatTargetLocation = Vector3.new(targetLocation.X, self.RootPart.Position.Y, targetLocation.Z)
	local delta = (flatTargetLocation - self.RootPart.Position)
	local distanceToTarget = delta.Magnitude
	local unit = distanceToTarget > 0.001 and delta.Unit or self.RootPart.CFrame.LookVector
	local lungeDistance = MovementShared.GetDesiredLungeDistance(distanceToTarget, attackSwingRange, maxLungeDistance)
	local lungeVelocity = lungeDistance / lungeDuration

	self.RootPart.CFrame = CFrame.lookAt(self.RootPart.Position, flatTargetLocation)
	if lungeDistance > 0 then
		self:ApplyLinearVelocity(unit * lungeVelocity, lungeDuration)
	end

	return true
end

function MovementEngine.Dash(self: MovementEngine): boolean
	if not self:IsActionEnabled() or not self:IsGrounded() then
		return false
	end

	local dashDuration = 0.32
	local dashSpeed = 24
	local dashDirection, usedDirectionalInput = GetCameraRelativeDashDirection(self.RootPart)
	local facingDirection = Vector3.new(self.RootPart.CFrame.LookVector.X, 0, self.RootPart.CFrame.LookVector.Z).Unit
	local isBackstep = (not usedDirectionalInput) or dashDirection:Dot(facingDirection) < -0.8
	local dashAnimation = if isBackstep then "Backstep" else "Dash"
	local dashAnimationId = self:GetAnimation(dashAnimation)
	StopActionAnimations(self)
	StopCurrentLocomotionAnimation(self)
	self:Play(dashAnimation)
	TrackActionAnimation(self, dashAnimationId)
	self:LockMovement(dashDuration)
	self:LockAction(dashDuration)
	local dashToken = ScheduleLocomotionResume(self, dashDuration)
	self:SetInvincibilityStatus(true)
	self:ApplyLinearVelocity(dashDirection * dashSpeed, dashDuration)
	task.delay(dashDuration, function()
		if self.LocomotionResumeToken ~= dashToken then
			return
		end

		self:SetInvincibilityStatus(false)
		self:Stop(dashAnimation)
		self.CurrentActionAnimationIds = {}
		self:UpdateMovementAnimation()
	end)

	return true
end

function MovementEngine.GetAnimation(self: MovementEngine, animation: string): string
	if animation == "Idle" then
		local equippedWeapon = WeaponServiceClient.GetEquippedWeaponData()
		local weaponClass = equippedWeapon and equippedWeapon.Class or "Sword"
		if weaponClass == "Claymore" and self.__Animations["IdleClaymore"] then
			return self.__Animations["IdleClaymore"]
		end
		if weaponClass == "Spear" and self.__Animations["IdleSpear"] then
			return self.__Animations["IdleSpear"]
		end
		if self.__Animations["Idle"] then
			return self.__Animations["Idle"]
		end
	end

	if self.__Animations[animation] then
		return self.__Animations[animation]
	end

	return ""
end

function MovementEngine.Play(self: MovementEngine, animation: string)
	local animId = self:GetAnimation(animation)
	if animId == "" then
		return
	end

	AnimationServiceClient.Animate(animId)
end

function MovementEngine.Stop(self: MovementEngine, animation: string)
	local animId = self:GetAnimation(animation)
	if animId == "" then
		return
	end

	AnimationServiceClient.StopAnimation(animId)
end

function MovementEngine.UpdateMovementAnimation(self: MovementEngine)
	local walkAnimation = self.__Animations["Walk"] or ""
	local idleAnimation = self:GetAnimation("Idle")
	if walkAnimation == "" and idleAnimation == "" then
		return
	end

	local isActivelyWalking = self.Humanoid.MoveDirection.Magnitude > 0.05
	local canPlayLocomotion = self:IsMovementEnabled()
		and self:IsActionEnabled()
		and self.Character.Parent ~= nil
	if not canPlayLocomotion or IsActionAnimationPlaying(self) then
		StopCurrentLocomotionAnimation(self)
		return
	end

	local desiredAnimation: string? = nil
	local desiredAnimationId: string? = nil
	if isActivelyWalking and walkAnimation ~= "" then
		desiredAnimation = "Walk"
		desiredAnimationId = walkAnimation
	elseif idleAnimation ~= "" then
		desiredAnimation = "Idle"
		desiredAnimationId = idleAnimation
	end

	if self.CurrentLocomotionAnimation == desiredAnimation and self.CurrentLocomotionAnimationId == desiredAnimationId then
		return
	end

	StopCurrentLocomotionAnimation(self)

	if desiredAnimation == "Walk" then
		self:Play("Walk")
		self.WalkAnimationPlaying = true
		self.CurrentLocomotionAnimation = "Walk"
		self.CurrentLocomotionAnimationId = desiredAnimationId
	elseif desiredAnimation == "Idle" then
		self:Play("Idle")
		self.IdleAnimationPlaying = true
		self.CurrentLocomotionAnimation = "Idle"
		self.CurrentLocomotionAnimationId = desiredAnimationId
	end
end

return MovementEngine
