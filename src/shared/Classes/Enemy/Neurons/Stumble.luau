--!strict

local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)

type Neuron = BrainTypes.Neuron

local Stumble = {}
Stumble.__index = Stumble
setmetatable(Stumble, SuperNeuron)

local function CanEnter(self: Neuron): boolean
	return self.Brain.PendingStumble == true
end

local function CanExit(self: Neuron): boolean
	return os.clock() >= self.__Attributes["ExitAt"]
end

local function OnEnter(self: Neuron): ()
	local rootPart = self.Brain.RootPart
	local movementEngine = self.Brain.MovementEngine
	local sourcePosition = self.Brain.StumbleSourcePosition
	local rootPosition = rootPart.Position

	self.Brain.PendingStumble = false
	self.Brain.StumbleSourcePosition = nil
	self.__Attributes["ExitAt"] = os.clock() + self.__Attributes["Duration"]

	movementEngine.Humanoid:MoveTo(rootPosition)
	movementEngine:CancelLinearVelocity()
	movementEngine:DisableMovement()
	movementEngine:ClearLookAt()
	movementEngine:ScheduleDeferTask(self.__Attributes["Duration"])

	local flatDirection = if sourcePosition
		then Vector3.new(rootPosition.X - sourcePosition.X, 0, rootPosition.Z - sourcePosition.Z)
		else -Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	local stumbleDirection = if flatDirection.Magnitude > 0.001
		then flatDirection.Unit
		else -Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z).Unit

	movementEngine:ApplyLinearVelocity(
		stumbleDirection * self.__Attributes["BackwardSpeed"],
		self.__Attributes["Duration"]
	)
end

local function OnExit(self: Neuron): ()
	return
end

local function OnUpdate(self: Neuron, _: number): ()
	return
end

function Stumble.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Interrupting", "Stumble")
	setmetatable(self, Stumble)

	self.__Attributes["Duration"] = 0.22
	self.__Attributes["BackwardSpeed"] = 12
	self.__Attributes["ExitAt"] = 0

	return self :: any
end

return Stumble
