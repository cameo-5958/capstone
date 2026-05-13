--!strict

-- Import neurons
local neurons = script.Parent.Neurons
local Stumble = require(neurons.Stumble)
local StrafePlayer = require(neurons.StrafePlayer)
local AttackPlayer = require(neurons.AttackPlayer)
local BackOffPlayer = require(neurons.BackOffPlayer)
local Aggro = require(neurons.Aggro)
local Wander = require(neurons.Wander)
local TrackPlayer = require(neurons.TrackPlayer)
local EscapePlayer = require(neurons.EscapePlayer)
local GrazeWander = require(neurons.GrazeWander)

-- Import brain
local BrainTypes = require(script.Parent.BrainTypes)
local BrainClass = require(script.Parent.BrainClass)
type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local Brains = {}

function Brains.Aggressive(movementEngine, range: number): Brain
	-- Create the brain
	local brain = BrainClass.new(movementEngine, {
		-- Interrupting
		Stumble.new(), -- Heavy hits interrupt into a short stumble
		Aggro.new(), -- Can get aggroed

		-- Core
		StrafePlayer.new(), -- Try to strafe before committing to an attack
		BackOffPlayer.new(), -- Creates space after attacking before strafing
		AttackPlayer.new(), -- Attacks once close enough to commit
		TrackPlayer.new(range), -- Tracks the player at this given range

		-- Passive
		Wander.new(range), -- Will wander if left alone
	})

	return brain
end

function Brains.PassivePrey(movementEngine, range: number): Brain
	local brain = BrainClass.new(movementEngine, {
		EscapePlayer.new(),
		GrazeWander.new(range),
	})

	return brain
end

return Brains
