--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AnimationServiceClient = require(ReplicatedStorage.Services.Animation.AnimationServiceClient)
local EnemyServiceClient = require(ReplicatedStorage.Services.Enemy.EnemyServiceClient)
local PlayerServiceClient = require(ReplicatedStorage.Services.Player.PlayerServiceClient)
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

local LIGHT_ATTACK_STAMINA_COST = 15
local HEAVY_ATTACK_STAMINA_COST = 25
local DASH_STAMINA_COST = 20

export type MovementEngine = SharedMovementEngine & {
	Character: Model,
	Humanoid: Humanoid,
	RootPart: Part,
	Speed: number,
	EntityUUID: number?,
	Player: Player?,
	WalkAnimationPlaying: boolean,
	__Animations: { string: string },
	__ComboState: {
		WeaponId: string?,
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
	self.__ComboState = {
		WeaponId = nil,
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
		self.__ComboState.WeaponId = nil
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
	if state.WeaponId ~= equippedWeapon.WeaponId or state.ComboId ~= combo.Id or expired then
		attackIndex = 1
	end

	local attack = combo.Attacks[math.clamp(attackIndex, 1, #combo.Attacks)]
	state.WeaponId = equippedWeapon.WeaponId
	state.ComboId = combo.Id
	state.AttackIndex = (attackIndex % #combo.Attacks) + 1
	state.LastAttackAt = now

	return attack.MovementLockedUntil or fallbackDuration
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
	if state.WeaponId ~= equippedWeapon.WeaponId or state.ComboId ~= combo.Id or expired then
		attackIndex = 1
	end

	return combo.Attacks[math.clamp(attackIndex, 1, #combo.Attacks)]
end

local function GetScaledStat(statName: string, fallback: number): number
	local statValue = PlayerServiceClient.GetStat(statName)
	if typeof(statValue) ~= "number" then
		return fallback
	end

	return statValue
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

	self.RootPart:PivotTo(CFrame.lookAt(self.RootPart.Position, self.RootPart.Position + desiredLook))
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

function MovementEngine.Attack(self: MovementEngine): boolean
	if not self:IsMovementEnabled() then
		return false
	end

	local equippedWeapon = WeaponServiceClient.GetEquippedWeaponData()
	if not equippedWeapon then
		return false
	end

	local weaponClass = equippedWeapon.Class or "Sword"
	local attackContext = equippedWeapon.AttackContext or {}

	if weaponClass == "Sword" or weaponClass == nil then
		local swordDefaults = {
			SightRange = 32,
			SwingRange = 4.5,
			MaxDashRange = 2.5,
			LungeDuration = 0.08,
			LockDuration = 0.35,
		}
		for key, value in pairs(swordDefaults) do
			if attackContext[key] == nil then
				attackContext[key] = value
			end
		end
	else
		for key, value in pairs({
			SightRange = 32,
			SwingRange = 4.5,
			MaxDashRange = 2.5,
			LungeDuration = 0.08,
			LockDuration = 0.35,
		}) do
			if attackContext[key] == nil then
				attackContext[key] = value
			end
		end
	end

	local attackSightRange = attackContext.SightRange
	local attackSwingRange = attackContext.SwingRange
	local maxLungeDistance = attackContext.MaxDashRange
	local lungeDuration = attackContext.LungeDuration
	local nextAttack = PeekNextComboAttack(self, equippedWeapon)
	local movementLockDuration = GetMovementLockDuration(self, equippedWeapon, attackContext.LockDuration)
	local isHeavyAttack = nextAttack ~= nil and nextAttack.IsHeavy == true
	local isNoStaminaAttack = nextAttack ~= nil and nextAttack.NoStamina == true
	local stamina = PlayerServiceClient.GetStat("Stamina") or 0
	local staminaConsumptionRate = GetScaledStat("StaminaConsumptionRate", 1)
	local attackStaminaCost = (isHeavyAttack and HEAVY_ATTACK_STAMINA_COST or LIGHT_ATTACK_STAMINA_COST) * staminaConsumptionRate

	if not isNoStaminaAttack and stamina < attackStaminaCost then
		return false
	end

	local target = self:GetTarget(self.RootPart.Position, attackSightRange)
	local targetLocation = Vector3.zero

	if not target then
		targetLocation = self.RootPart.Position + self.RootPart.CFrame.LookVector.Unit * attackSwingRange
	else
		targetLocation = GetProjectedTargetLocation(target, 0.12)
	end

	self:LockMovement(movementLockDuration)

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
	if not self:IsMovementEnabled() or not self:IsGrounded() then
		return false
	end

	local stamina = PlayerServiceClient.GetStat("Stamina") or 0
	local staminaConsumptionRate = GetScaledStat("StaminaConsumptionRate", 1)
	if stamina < (DASH_STAMINA_COST * staminaConsumptionRate) then
		return false
	end

	local dashDuration = 0.48
	local dashSpeed = 16
	local dashDirection, usedDirectionalInput = GetCameraRelativeDashDirection(self.RootPart)
	local facingDirection = Vector3.new(self.RootPart.CFrame.LookVector.X, 0, self.RootPart.CFrame.LookVector.Z).Unit
	local isBackstep = (not usedDirectionalInput) or dashDirection:Dot(facingDirection) < -0.8
	local dashAnimation = if isBackstep then "Backstep" else "Dash"
	self:Stop("Attack")
	self:Play(dashAnimation)
	self:DisableMovement()
	self:SetInvincibilityStatus(true)
	self:ScheduleDeferTask(dashDuration)
	self:ApplyLinearVelocity(dashDirection * dashSpeed, dashDuration)
	task.delay(dashDuration, function()
		self:Stop(dashAnimation)
	end)

	return true
end

function MovementEngine.GetAnimation(self: MovementEngine, animation: string): string
	if self.__Animations[animation] then
		return self.__Animations[animation]
	end

	return self.__Animations["Walk"] or ""
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
	if walkAnimation == "" then
		return
	end

	local shouldWalk = self:IsMovementEnabled()
		and self.Humanoid.MoveDirection.Magnitude > 0.05
		and self.Character.Parent ~= nil

	if shouldWalk and not self.WalkAnimationPlaying then
		self:Play("Walk")
		self.WalkAnimationPlaying = true
	elseif not shouldWalk and self.WalkAnimationPlaying then
		self:Stop("Walk")
		self.WalkAnimationPlaying = false
	end
end

return MovementEngine
