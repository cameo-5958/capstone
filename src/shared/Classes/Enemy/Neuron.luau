--!strict
-- Neuron class for Enemy AI

-- Import Neuron type
local BrainTypes = require(script.Parent.BrainTypes)

type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local Neuron = {}
Neuron.__index = Neuron

-- Create a Neuron superclass
function Neuron.new(
	canEnter: (self: Neuron) -> boolean,
	canExit: (self: Neuron) -> boolean,
	onEnter: (self: Neuron) -> (),
	onExit: (self: Neuron) -> (),
	onUpdate: (self: Neuron, dt: number) -> (),

	priority: BrainTypes.Priority
): Neuron
	local self = setmetatable({}, Neuron)

	self.CanEnter = canEnter
	self.CanExit = canExit
	self.OnEnter = onEnter
	self.OnExit = onExit
	self.OnUpdate = onUpdate

	self.Priority = priority

	self.__Attributes = {}

	return self :: any
end

return Neuron
