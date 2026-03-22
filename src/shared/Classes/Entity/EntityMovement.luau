--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationServiceServer = require(ReplicatedStorage.Services.Animation.AnimationServiceServer)
local EntityTypes = require(script.Parent.EntityTypes)
type Entity = EntityTypes.Entity

local Handler: RemoteEvent = ReplicatedStorage.Services.Enemy:WaitForChild("EnemyHandler")

local MovementEngine = {}
MovementEngine.__index = MovementEngine

export type MovementEngine = {
	-- Store the RootPart and Humanoid since we don't
	-- need to store full Entity
	Character: Model,
	Humanoid: Humanoid,
	RootPart: Part,
	Speed: number,
	Entity: Entity,
	RootAttachment: Attachment?,

	-- MoveToFinished
	MoveToFinished: CustomEvent,

	-- Identifier
	EntityUUID: string,

	-- Moving Metadata
	MovementEnabled: boolean,
	Invincible: boolean,
	FacingTarget: Vector3?,
	LookAlign: AlignOrientation?,

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
	IsMovementEnabled: (MovementEngine) -> boolean,
	LookAt: (MovementEngine, Vector3) -> (),
	ClearLookAt: (MovementEngine) -> (),

	-- Public API
	Attack: (MovementEngine) -> (),
	Dash: (MovementEngine) -> (),

	-- GetTarget API
	GetTarget: (MovementEngine, Vector3, number) -> Entity,

	-- Constructors
	new: (Entity) -> (),
	init: (MovementEngine) -> (),

	-- Animations
	__Animations: { string: string },
	Play: (MovementEngine, string) -> (),
	Stop: (MovementEngine, string) -> (),
}

function MovementEngine.__tostring(self: MovementEngine): string
	return "MovementEngine<" .. (self.EntityUUID or self.Character.Name) .. ">"
end

function MovementEngine.init(self: MovementEngine): ()
	-- Default state of the engine is to have movement enabled
	self.MovementEnabled = true
	self.Invincible = false
	self.FacingTarget = nil

	self:DeferTask()
end

-- All Entity engines take a class of
-- type Entity in order to instantiate
function MovementEngine.new(entity: Entity): MovementEngine
	local self = setmetatable({}, MovementEngine)

	-- Initialize Engine state table
	self.States = {}
	self.Character = entity.Character
	self.Humanoid = entity.Character:FindFirstChild("Humanoid") :: Humanoid
	self.RootPart = entity.RootPart
	self.Entity = entity
	self.RootAttachment = self.RootPart:FindFirstChild("RootAttachment") :: Attachment?
	self.EntityUUID = entity.UUID
	self.Speed = entity.__Stats["Speed"]
	self.__Animations = entity.__Animations

	self.MoveToFinished = self.Humanoid.MoveToFinished;
	-- Initialize other states
	((self :: any) :: MovementEngine):init()

	return (self :: any) :: MovementEngine
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

	Handler:FireAllClients("LinearVelocity", {
		UUID = self.EntityUUID,
		Velocity = force,
		Duration = time_,
	})
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

	Handler:FireAllClients("CancelLinearVelocity", {
		UUID = self.EntityUUID,
	})
end

-- Utility method for iframe management
function MovementEngine.SetInvincibilityStatus(self: MovementEngine, status: boolean): ()
	-- Run different code depending on network owner

	-- Server
	-- Send message w uuid, status
	print("Server:", status)

	-- Set state to self
	self.Invincible = status
end

-- Setting movement to 0 and disabling
function MovementEngine.DisableMovement(self: MovementEngine)
	-- Set state and speed to 0
	self.MovementEnabled = false
	self.Humanoid.WalkSpeed = 0
end

-- Method for resetting movement, etc. after
-- iframes
function MovementEngine.DeferTask(self: MovementEngine)
	-- Task has successfully been deferred, grant
	-- movement speed and disable iframes
	self.MovementEnabled = true
	self:SetInvincibilityStatus(false)

	self.Humanoid.WalkSpeed = self.Speed

	-- Destroy extras, if any
	self:CancelLinearVelocity()
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
	return self.MovementEnabled
end

local function GetLookAlign(self: MovementEngine): AlignOrientation?
	if self.LookAlign and self.LookAlign.Parent then
		return self.LookAlign
	end

	local attachment = self.RootAttachment or self.RootPart:FindFirstChild("RootAttachment")
	if not attachment then
		return nil
	end

	local align = self.RootPart:FindFirstChild("LookAlign") :: AlignOrientation?
	if not align then
		align = Instance.new("AlignOrientation")
		align.Name = "LookAlign"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment :: Attachment
		align.Responsiveness = 200
		align.RigidityEnabled = false
		align.Enabled = false
		align.Parent = self.RootPart
	end

	self.RootAttachment = attachment :: Attachment
	self.LookAlign = align

	return align
end

function MovementEngine.LookAt(self: MovementEngine, target: Vector3): ()
	self.FacingTarget = target

	local align = GetLookAlign(self)
	if align then
		local myPos = self.RootPart.Position
		local flatTarget = Vector3.new(target.X, myPos.Y, target.Z)
		align.CFrame = CFrame.lookAt(myPos, flatTarget)
		align.Enabled = true
		self.Humanoid.AutoRotate = false
	end

	Handler:FireAllClients("Face", {
		UUID = self.EntityUUID,
		LookAt = target,
	})
end

function MovementEngine.ClearLookAt(self: MovementEngine): ()
	self.FacingTarget = nil

	if self.LookAlign then
		self.LookAlign.Enabled = false
	end
	self.Humanoid.AutoRotate = true

	Handler:FireAllClients("Face", {
		UUID = self.EntityUUID,
		LookAt = nil,
	})
end

-- Three movement types: Attack, Block, Dash
function MovementEngine.Attack(self: MovementEngine): ()
	-- If movement is not currently allowed, do nothing
	if not self:IsMovementEnabled() then
		return
	end

	-- All tunable constants
	local __sight_range = 32
	local __cooldown = 1
	local __teleport_to_range = 4
	local __teleport_maximum_threshold = 18
	local __no_target_teleport_distance = 6

	-- Find the closest enemy using the
	-- given API
	local target = self:GetTarget(self.RootPart.Position, 32)
	local targetLocation = Vector3.zero

	if not target then
		targetLocation = self.RootPart.Position + self.RootPart.CFrame.LookVector.Unit * 50
	else
		targetLocation = target.RootPart.Position
	end

	-- Disable movement and set iframes
	self:DisableMovement()

	-- self:SetInvincibilityStatus(true)

	-- Schedule task to re-enable movement and disable iframes after 1 second
	self:ScheduleDeferTask(__cooldown)

	-- Find the distance between my RootPart and the target
	local delta = (targetLocation - self.RootPart.Position)
	local distance = delta.Magnitude
	local unit = delta.Unit

	-- Using the AttackContext, we'll decide how far
	-- we want to teleport
	local destination

	-- Snap to position (targetLocation + unit * 3) if
	-- 4 < distance < 16
	if distance <= __teleport_maximum_threshold then
		destination = (targetLocation - unit * __teleport_to_range)
	else
		-- Teleport 4 units forward
		destination = self.RootPart.Position + unit * __no_target_teleport_distance
	end

	-- New CFrame
	self.RootPart:PivotTo(CFrame.lookAt(destination, targetLocation))
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

-- Just moving
function MovementEngine.MoveTo(self: MovementEngine, position: Vector3, lookAt: Vector3?): ()
	-- Reject if movement is disabled
	if not self:IsMovementEnabled() then
		return
	end

	if lookAt then
		self:LookAt(lookAt)
	else
		self:ClearLookAt()
	end

	self.Humanoid:MoveTo(position)
	-- Broadcast moveto to everyone
	Handler:FireAllClients("Move", {
		UUID = self.EntityUUID,
		Position = position,
		LookAt = lookAt,
	})
end

-- Just pivoting
function MovementEngine.PivotTo(self: MovementEngine, cf: CFrame): ()
	-- Reject if movement is disabled
	if not self:IsMovementEnabled() then
		return
	end

	self.FacingTarget = nil
	self.RootPart:PivotTo(cf)
	-- Broadcast moveto to everyone
	Handler:FireAllClients("Pivot", {
		UUID = self.EntityUUID,
		CFrame = cf,
	})
end

-- Animate myself
function MovementEngine.Play(self: MovementEngine, animId: string)
	-- Hand myself in to the animator
	AnimationServiceServer.Animate(self.EntityUUID, self.__Animations[animId])
end

-- End an animation
function MovementEngine.Stop(self: MovementEngine, animId: string)
	-- Hand myself in again
	AnimationServiceServer.Stop(self.EntityUUID, self.__Animations[animId])
end

return MovementEngine
