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
local function CanEnter(_: Neuron): boolean
	-- You can always enter
	print("Hitting wander neuron")
	return true
end

local function CanExit(self: Neuron): boolean
	-- Exit once detection happens or if our
	-- pause time is up

	return self.Brain:GetTargetPlayer(32) ~= nil or self.__Attributes["ExitThreshold"] < 0
end

local function OnEnter(self: Neuron): ()
	-- Select a place to wander to
	local pos = self.Brain.RootPart.Position
	local delta = Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))

	while self.Brain:Obstruction(pos + delta) do
		delta = Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
	end

	self.__Attributes["TargetLocation"] = pos + delta
	self.Brain.MovementEngine:MoveTo(self.__Attributes["TargetLocation"])

	self.__Attributes["MoveToFinished"] = self.Brain.MovementEngine.MoveToFinished:Connect(function()
		self.__Attributes["StartExitSequence"] = true
	end)

	self.__Attributes["StartExitSequence"] = false
	self.__Attributes["ExitThreshold"] = math.random(3500, 6500) / 1000
end

local function OnExit(self: Neuron): ()
	-- Exiting logic

	-- Set MoveTo to my own position
	self.Brain.MovementEngine:MoveTo(self.Brain.RootPart.Position)
end

local function OnUpdate(self: Neuron, dt: number): ()
	-- Check if MoveToFinished
	if self.__Attributes["StartExitSequence"] then
		self.__Attributes["ExitThreshold"] -= dt
	end
end

-- Neuron constructor
function __New_Neuron.new(range: number): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Idle", "Wander")

	setmetatable(self, __New_Neuron)

	self.__Attributes["Range"] = range
	return self :: any
end

-- Return the class
return __New_Neuron
