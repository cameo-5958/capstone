--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationServiceClient = require(ReplicatedStorage.Services.Animation.AnimationServiceClient)
local EnemyServiceClient = require(ReplicatedStorage.Services.Enemy.EnemyServiceClient)
local PlayerConfig = require(ReplicatedStorage.Database.Players.Default.Data)
local EntityTypes = require(script.Parent.EntityTypes)
type Entity = EntityTypes.Entity

local MovementEngine = {}
MovementEngine.__index = MovementEngine

local function GetDesiredLungeDistance(distanceToTarget: number, swingRange: number, maxLungeDistance: number): number
	return math.min(maxLungeDistance, math.max(0, distanceToTarget - swingRange))
end

export type MovementEngine = {
	-- Store the RootPart and Humanoid since we don't
	-- need to store full Entity
	Character: Model,
	Humanoid: Humanoid,
	RootPart: Part,
	Speed: number,

	-- Identifier
	EntityUUID: number?,
	Player: Player?,

	-- Moving Metadata
	MovementEnabled: boolean,
	AllMovementDisabled: boolean,
	Invincible: boolean,
	WalkAnimationPlaying: boolean,

	-- Deferred task location
	DeferredCancelTask: thread?,
	DeferredVelocityCancelTask: thread?,

	-- Methods
	ApplyLinearVelocity: (MovementEngine, Vector3, number) -> (),
	CancelLinearVelocity: (MovementEngine) -> (),
	DeferTask: (MovementEngine) -> (),
	ScheduleDeferTask: (MovementEngine, number) -> (),
	SetInvincibilityStatus: (MovementEngine, boolean) -> (),
	DisableMovement: (MovementEngine) -> (),
	DisableAllMovement: (MovementEngine) -> (),
	EnableAllMovement: (MovementEngine) -> (),
	LockMovement: (MovementEngine, number) -> (),
	UnlockMovement: (MovementEngine) -> (),
	IsMovementEnabled: (MovementEngine) -> boolean,

	-- Public API
	Attack: (MovementEngine) -> (),
	Dash: (MovementEngine) -> (),

	-- GetTarget API
	GetTarget: (MovementEngine, Vector3, number) -> Entity,

	-- Animating
	__Animations: { string: string },
	GetAnimation: (MovementEngine, string) -> string,
	Play: (MovementEngine, string) -> (),
	Stop: (MovementEngine, string) -> (),
	UpdateMovementAnimation: (MovementEngine) -> (),

	-- Constructors
	new: (Entity) -> (),
	lnew: (Player) -> (),
	init: (MovementEngine) -> (),
}

function MovementEngine.__tostring(self: MovementEngine): string
	return "MovementEngine<" .. (self.EntityUUID or self.Character.Name) .. ">"
end

function MovementEngine.init(self: MovementEngine): ()
	-- Default state of the engine is to have movement enabled
	self.MovementEnabled = true
	self.AllMovementDisabled = false
	self.Invincible = false
	self.WalkAnimationPlaying = false

	-- Enable movement
	self:DeferTask()
end

if RunService:IsServer() then
	-- All Entity engines take a class of
	-- type Entity in order to instantiate
	function MovementEngine.new(entity: Entity): MovementEngine
		local self = setmetatable({}, MovementEngine)

		-- Initialize Engine state table
		self.States = {}
		self.Character = entity.Character
		self.Humanoid = entity.Character:FindFirstChild("Humanoid")
		self.RootPart = entity.RootPart
		self.EntityUUID = entity.UUID
		self.Speed = entity.__Stats["Speed"];
		-- Initialize other states
		((self :: any) :: MovementEngine):init()

		return (self :: any) :: MovementEngine
	end
else
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local function HasLineOfSight(self: MovementEngine, target: Entity): boolean
		raycastParams.FilterDescendantsInstances = { self.Character }

		local origin = self.RootPart.Position
		local targetPos = target.RootPart.Position
		local delta = targetPos - origin
		local result = workspace:Raycast(origin, delta, raycastParams)

		if not result then
			return false
		end

		return result.Instance:IsDescendantOf(target.Character)
	end

	-- Players have a slightly different
	-- instantiation process
	function MovementEngine.lnew(): MovementEngine
		local lp = Players.LocalPlayer
		local chr = lp.Character or lp.CharacterAdded:Wait()
		local self = setmetatable({}, MovementEngine)

		-- Initialize Engine state table
		self.States = {}
		self.Character = chr
		self.Humanoid = chr:WaitForChild("Humanoid")
		self.RootPart = chr.PrimaryPart :: Part
		self.Player = lp
		self.Speed = 12
		self.__Animations = table.clone(PlayerConfig.__Animations or {});
		-- Initialize other states
		((self :: any) :: MovementEngine):init()

		self.Humanoid.Running:Connect(function()
			self:UpdateMovementAnimation()
		end)
		self.Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			self:UpdateMovementAnimation()
		end)

		-- Movement would detect Enemies using
		-- local EnemyService and choose closest one

		return (self :: any) :: MovementEngine
	end

	-- GetTarget finds the closest visible enemy
	function MovementEngine.GetTarget(self: MovementEngine, pos: Vector3, sight: number?): Entity
		local closest: Entity? = nil
		local closestDistance = sight or 64

		for _, enemy in pairs(EnemyServiceClient.GetAll()) do
			local distance = (enemy.RootPart.Position - pos).Magnitude
			if distance < closestDistance and HasLineOfSight(self, enemy) then
				closest = enemy
				closestDistance = distance
			end
		end

		return closest :: Entity
	end
end

function MovementEngine.ApplyLinearVelocity(self: MovementEngine, force: Vector3, time_: number): ()
	-- Create a new Attachment and LinearVelocity and parent to Character
	local lv = self.Character:FindFirstChild("LinearVelocity") :: LinearVelocity or Instance.new("LinearVelocity")
	lv.Parent = self.Character
	self.RootPart.AssemblyLinearVelocity = Vector3.zero
	lv.VectorVelocity = force
	lv.Attachment0 = self.RootPart:FindFirstChild("RootAttachment") :: Attachment
	lv.MaxForce = 999999

	if self.DeferredVelocityCancelTask then
		task.cancel(self.DeferredVelocityCancelTask)
	end

	self.DeferredVelocityCancelTask = task.delay(time_, function()
		self.DeferredVelocityCancelTask = nil

		local activeLv = self.Character:FindFirstChild("LinearVelocity")
		if activeLv then
			activeLv:Destroy()
		end
		self.RootPart.AssemblyLinearVelocity = Vector3.zero
	end)
end

function MovementEngine.CancelLinearVelocity(self: MovementEngine): ()
	if self.DeferredVelocityCancelTask then
		task.cancel(self.DeferredVelocityCancelTask)
		self.DeferredVelocityCancelTask = nil
	end

	local lv = self.Character:FindFirstChild("LinearVelocity")
	if lv then
		lv:Destroy()
	end
	self.RootPart.AssemblyLinearVelocity = Vector3.zero
end

-- Utility method for iframe management
function MovementEngine.SetInvincibilityStatus(self: MovementEngine, status: boolean): ()
	-- Run different code depending on network owner
	if RunService:IsServer() then
		-- Server
		-- Send message w uuid, status
		print("Server:", status)
	else
		-- Client
		-- Send message w status
		print("Client:", status)
	end

	-- Set state to self
	self.Invincible = status
end

-- Setting movement to 0 and disabling
function MovementEngine.DisableMovement(self: MovementEngine)
	-- Set state and speed to 0
	self.MovementEnabled = false
	self.Humanoid.WalkSpeed = 0
	self:UpdateMovementAnimation()
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

function MovementEngine.LockMovement(self: MovementEngine, duration: number)
	self:DisableMovement()
	self:ScheduleDeferTask(duration)
end

function MovementEngine.UnlockMovement(self: MovementEngine)
	self:DeferTask()
end

-- Method for resetting movement, etc. after
-- iframes
function MovementEngine.DeferTask(self: MovementEngine)
	if self.AllMovementDisabled then
		self.MovementEnabled = false
		self.Humanoid.WalkSpeed = 0
		self:SetInvincibilityStatus(false)
		self:CancelLinearVelocity()
		self:UpdateMovementAnimation()
		return
	end

	-- Task has successfully been deferred, grant
	-- movement speed and disable iframes
	self.MovementEnabled = true
	self:SetInvincibilityStatus(false)

	self.Humanoid.WalkSpeed = self.Speed

	-- Destroy extras, if any
	self:CancelLinearVelocity()
	self:UpdateMovementAnimation()
end

-- Utility method for setting defer task
function MovementEngine.ScheduleDeferTask(self: MovementEngine, time: number)
	-- Cancel the previous task, if any
	if self.DeferredCancelTask then
		task.cancel(self.DeferredCancelTask)
	end

	-- Create a new task delayed time "time"
	-- set to trigger in the future
	self.DeferredCancelTask = task.delay(time, function()
		self.DeferredCancelTask = nil
		self:DeferTask()
	end)
end

-- Ensure movement is currently allowed
function MovementEngine.IsMovementEnabled(self: MovementEngine): boolean
	return self.MovementEnabled and not self.AllMovementDisabled
end

-- Three movement types: Attack, Block, Dash
function MovementEngine.Attack(self: MovementEngine): ()
	-- If movement is not currently allowed, do nothing
	if not self:IsMovementEnabled() then
		return
	end

	-- All tunable constants
	local _ATTACK_SIGHT_RANGE = 32
	local _ATTACK_SWING_RANGE = 4.5
	local _MAX_LUNGE_DISTANCE = 2.5
	local _LUNGE_DURATION = 0.08
	local __movement_lock_duration = 0.35

	-- Find the closest enemy using the
	-- given API
	local target = self:GetTarget(self.RootPart.Position, _ATTACK_SIGHT_RANGE)
	local targetLocation = Vector3.zero

	if not target then
		targetLocation = self.RootPart.Position + self.RootPart.CFrame.LookVector.Unit * _ATTACK_SWING_RANGE
	else
		targetLocation = target.RootPart.Position
	end

	-- Lock movement briefly after attacking so input cannot immediately cancel the lunge.
	self:LockMovement(__movement_lock_duration)

	-- Find the distance between my RootPart and the target
	local flatTargetLocation = Vector3.new(targetLocation.X, self.RootPart.Position.Y, targetLocation.Z)
	local delta = (flatTargetLocation - self.RootPart.Position)
	local distanceToTarget = delta.Magnitude
	local unit = distanceToTarget > 0.001 and delta.Unit or self.RootPart.CFrame.LookVector
	local lungeDistance = GetDesiredLungeDistance(distanceToTarget, _ATTACK_SWING_RANGE, _MAX_LUNGE_DISTANCE)
	local lungeVelocity = lungeDistance / _LUNGE_DURATION

	-- Face the target direction, then apply a short lunge via LinearVelocity.
	self.RootPart.CFrame = CFrame.lookAt(self.RootPart.Position, flatTargetLocation)
	if lungeDistance > 0 then
		self:ApplyLinearVelocity(unit * lungeVelocity, _LUNGE_DURATION)
	end
end

-- Dashing
function MovementEngine.Dash(self: MovementEngine): ()
	-- Reject if movement is disabled
	if not self:IsMovementEnabled() then
		return
	end

	-- Dash in either the direction the LookVector is
	-- currently pointing towards or the movement direction
	local dashDirection = self.RootPart.CFrame.LookVector.Unit

	-- Disable movement and give invincibility
	self:DisableMovement()
	self:SetInvincibilityStatus(true)

	-- Queue DeferTask
	self:ScheduleDeferTask(0.3)

	-- Apply an impulse
	self:ApplyLinearVelocity(dashDirection * 36, 0.3)
end

-- Getting an animation
function MovementEngine.GetAnimation(self: MovementEngine, animation: string): string
	if self.__Animations[animation] then
		return self.__Animations[animation]
	end

	return self.__Animations["Walk"] or ""
end

-- Animating
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
