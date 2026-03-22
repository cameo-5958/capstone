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
	-- Enter if the brain is aggroed

	if self.Brain.Aggro then
		self.Brain.Aggro = false
		return true
	end

	return false
end

local function CanExit(_: Neuron): boolean
	-- We want to exit immediately
	return true
end

local function OnEnter(_: Neuron): ()
	-- Entering logic
end

local function OnExit(_: Neuron): ()
	-- Exiting logic
end

local function OnUpdate(_: Neuron, _: number): ()
	-- Placeholder
end

-- Neuron constructor
function __New_Neuron.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Interrupting", "Aggro")

	setmetatable(self, __New_Neuron)
	return self :: any
end

-- Return the class
return __New_Neuron
