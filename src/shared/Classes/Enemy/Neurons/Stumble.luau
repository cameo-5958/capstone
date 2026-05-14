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

	movementEngine:Stop("Attack")
	movementEngine:Stop("StrafeLeft")
	movementEngine:Stop("StrafeRight")

	if movementEngine.__Animations["Stumble"] then
		movementEngine:Play("Stumble")
	end

	movementEngine:MoveTo(rootPosition)
	movementEngine:CancelLinearVelocity()
	movementEngine:DisableMovement()
	movementEngine:ClearLookAt()
	movementEngine:ScheduleDeferTask(self.__Attributes["Duration"])

	local fallbackDirection = -Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z).Unit
	local flatDirection = fallbackDirection
	if sourcePosition then
		local sourceDelta = Vector3.new(rootPosition.X - sourcePosition.X, 0, rootPosition.Z - sourcePosition.Z)
		if sourceDelta.Magnitude > 0.001 then
			flatDirection = sourceDelta.Unit
		end
	end

	movementEngine:ApplyLinearVelocity(
		flatDirection * self.__Attributes["BackwardSpeed"],
		self.__Attributes["Duration"]
	)
end

local function OnExit(self: Neuron): ()
	if self.Brain.MovementEngine.__Animations["Stumble"] then
		self.Brain.MovementEngine:Stop("Stumble")
	end

	return
end

local function OnUpdate(self: Neuron, _: number): ()
	return
end

function Stumble.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Interrupting", "Stumble")
	setmetatable(self, Stumble)

	self.__Attributes["Duration"] = 0.32
	self.__Attributes["BackwardSpeed"] = 12
	self.__Attributes["ExitAt"] = 0

	return self :: any
end

return Stumble
