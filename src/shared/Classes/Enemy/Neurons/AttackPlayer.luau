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
	return true
end

local function CanExit(self: Neuron): boolean
	-- Exiting gateway
	return false
end

local function OnEnter(self: Neuron): ()
	-- Entering logic
end

local function OnExit(self: Neuron): ()
	-- Exiting logic
end

local function OnUpdate(self: Neuron, dt: number): ()
	-- Placeholder
end

-- Neuron constructor
function __New_Neuron.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Core")

	setmetatable(self, __New_Neuron)
	return self :: any
end

-- Return the class
return __New_Neuron
