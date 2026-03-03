--!strict

-- Import neurons
local neurons = script.Parent.Neurons
local StrafePlayer = require(neurons.StrafePlayer)
local Aggro = require(neurons.Aggro)
local Wander = require(neurons.Wander)
local TrackPlayer = require(neurons.TrackPlayer)

-- Import brain
local BrainTypes = require(script.Parent.BrainTypes)
local Brain = require(script.Parent.EnemyBrain)
type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local Brains = {}

function Brains.Aggressive(movementEngine, range: number): Brain
	-- Create the brain
	local brain = Brain.new(movementEngine, {
		-- Interrupting
		Aggro.new(), -- Can get aggroed

		-- Core
		TrackPlayer.new(range), -- Tracks the player at this given range
		StrafePlayer.new(), -- Will Strafe with higher priority than attacks

		-- Passive
		Wander.new(range), -- Will wander if left alone
	})

	return brain
end

return Brains
