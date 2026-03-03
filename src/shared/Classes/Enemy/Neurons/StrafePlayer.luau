--!strict

-- Import Neuron
local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)

type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

-- Create the subclass
local __New_Neuron = {}
__New_Neuron.__index = __New_Neuron
setmetatable(__New_Neuron, SuperNeuron)

-- Neuron methods
local function CanEnter(self: Neuron): boolean
	-- Entering gateway
	-- This is HIGHER PRIORITY than attacking
	-- but has a decreasing chance of entry

	-- We'll attempt to enter if
	-- - if we're within 4 and 8 distance of the player
	-- - if we pass the strafe threshold

	-- We won't reaggro - we'll just try and attack
	-- the currently targetted player

	if self.Brain:Delta(self.Brain.Target).Magnitude < self.__Attributes["AttackRange"] * 1.2 then
		-- Calculate chance that we can enter
		if math.random() < (1 - self.__Attributes["Strafes"] * 0.2) then
			return true
		else
			-- Reset strafes since we're attacking now
			self.__Attributes["Strafes"] = 0
		end
	end

	-- Refuse to enter
	return false
end

local function CanExit(self: Neuron): boolean
	-- Exiting gateway
	return false
end

local function OnEnter(self: Neuron): ()
	-- Increase the amount of strafes we've done
	self.__Attributes["Strafes"] += 1

	-- Starting angle
	local delta = -self.Brain:Delta(self.Brain.Target)
	local startTheta = math.atan2(delta.Z, delta.X)

	-- Pick a random direction and goal
	local direction = math.random() > 0.5 and 1 or -1

	self.__Attributes["Direction"] = direction
	self.__Attributes["CurrentTheta"] = startTheta
	self.__Attributes["TargetTheta"] = startTheta + (math.pi * math.random(0.25, 0.75) * direction)
end

local function OnExit(self: Neuron): ()
	-- Exiting logic
end

local function OnUpdate(self: Neuron, dt: number): ()
	-- Updating
	local targetPos = (self.Brain.Target.PrimaryPart :: Part).Position
	local dir = self.__Attributes["Direction"]

	self.__Attributes["CurrentTheta"] += self.Brain.MovementEngine.Speed * dt * dir
	local theta = self.__Attributes["CurrentTheta"]

	-- Calculate new position
	local offset = Vector3.new(math.cos(theta), 0, math.sin(theta)) * self.Brain:Delta(self.Brain.Target).Magnitude
	local goalPos = targetPos + offset

	-- Apply movement
	self.Brain.MovementEngine:PivotTo(CFrame.lookAt(goalPos, targetPos))
end

-- Neuron constructor
function __New_Neuron.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Core")

	setmetatable(self, __New_Neuron)
	self.__Attributes["Strafes"] = 0
	self.__Attributes["AttackRange"] = 4
	return self :: any
end

-- Return the class
return __New_Neuron
