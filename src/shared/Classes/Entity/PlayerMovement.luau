--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EnemyServiceClient = require(ReplicatedStorage.Services.Enemy.EnemyServiceClient)
local EntityTypes = require(script.Parent.EntityTypes)
type Entity = EntityTypes.Entity

local MovementEngine = {}
MovementEngine.__index = MovementEngine

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
	Invincible: boolean,

	-- Deferred task location
	DeferredCancelTask: thread?,

	-- Methods
	Impulse: (MovementEngine, Vector3, number) -> (),
	DeferTask: (MovementEngine) -> (),
	ScheduleDeferTask: (MovementEngine, number) -> (),
	SetInvincibilityStatus: (MovementEngine, boolean) -> (),
	DisableMovement: (MovementEngine) -> (),
	IsMovementEnabled: (MovementEngine) -> boolean,

	-- Public API
	Attack: (MovementEngine) -> (),
	Dash: (MovementEngine) -> (),

	-- GetTarget API
	GetTarget: (MovementEngine, Vector3, number) -> Entity,

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
	self.Invincible = false

	-- Enable movement
	self:DeferTask()
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
	-- Initialize other states
	((self :: any) :: MovementEngine):init()

	-- Movement would detect Enemies using
	-- local EnemyService and choose closest one

	return (self :: any) :: MovementEngine
end

-- GetTarget is a wrapper for ClosestEnemy
function MovementEngine.GetTarget(_: MovementEngine, pos: Vector3, sight: number?): Entity
	return EnemyServiceClient.GetClosest(pos, sight)
end

-- Utility method for applying Velocity
function MovementEngine.Impulse(self: MovementEngine, force: Vector3, time_: number): ()
	-- Create a new Attachment and LinearVelocity and parent to Character
	local lv = self.Character:FindFirstChild("LinearVelocity") :: LinearVelocity or Instance.new("LinearVelocity")
	lv.Parent = self.Character
	lv.VectorVelocity = force
	lv.Attachment0 = self.RootPart:FindFirstChild("RootAttachment") :: Attachment
	lv.MaxForce = 999999

	-- Set to remove soon
	self:ScheduleDeferTask(time_)
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
	local lv = self.Character:FindFirstChild("LinearVelocity")
	if lv then
		lv:Destroy()
	end
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
		self:DeferTask()
	end)
end

-- Ensure movement is currently allowed
function MovementEngine.IsMovementEnabled(self: MovementEngine): boolean
	return self.MovementEnabled
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
	self:Impulse(dashDirection * 36, 0.3)
end

return MovementEngine
