--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	return weaponClass == "Sword" or weaponClass == "Claymore"
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

local function IsBowEquipped(): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil and character:GetAttribute("ForceFaceCamera") == true
end

local function GetProjectedTargetLocation(target: Entity, leadTime: number): Vector3
	local rootPart = target.RootPart
	local velocity = rootPart.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	return rootPart.Position + flatVelocity * leadTime
end

if RunService:IsServer() then
	function MovementEngine.new(entity: Entity): MovementEngine
		local self = setmetatable({}, MovementEngine)

		self.States = {}
		self.Character = entity.Character
		self.Humanoid = entity.Character:FindFirstChild("Humanoid")
		self.RootPart = entity.RootPart
		self.EntityUUID = entity.UUID
		self.Speed = entity:GetStat("Speed");
		((self :: any) :: MovementEngine):init()

		return (self :: any) :: MovementEngine
	end
else
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
	self.RootPart.CFrame = CFrame.lookAt(self.RootPart.Position, self.RootPart.Position + flatLook.Unit)
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

function MovementEngine.Attack(self: MovementEngine): ()
	if not self:IsMovementEnabled() then
		return
	end

	local equippedWeapon = WeaponServiceClient.GetEquippedWeaponData()
	if not equippedWeapon then
		return
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
	local movementLockDuration = GetMovementLockDuration(self, equippedWeapon, attackContext.LockDuration)

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
end

function MovementEngine.Dash(self: MovementEngine): ()
	if not self:IsMovementEnabled() or not self:IsGrounded() then
		return
	end

	local dashDuration = 0.36
	local dashSpeed = 30
	local dashDirection = self.RootPart.CFrame.LookVector.Unit
	self:Stop("Attack")
	self:Play("Dash")
	self:DisableMovement()
	self:SetInvincibilityStatus(true)
	self:ScheduleDeferTask(dashDuration)
	self:ApplyLinearVelocity(dashDirection * dashSpeed, dashDuration)
	task.delay(dashDuration, function()
		self:Stop("Dash")
	end)
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
