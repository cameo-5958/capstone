--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainTypes = require(script.Parent.BrainTypes)

type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local EnemyBrainModule = nil :: any

local function GetEnemyBrainModule()
	if EnemyBrainModule == nil then
		EnemyBrainModule = require(ReplicatedStorage.Classes.Enemy:WaitForChild("EnemyBrain") :: ModuleScript)
	end

	return EnemyBrainModule
end

local BrainClass = {}

function BrainClass.new(movementEngine, neurons: { Neuron }): Brain
	return GetEnemyBrainModule().new(movementEngine, neurons)
end

return table.freeze(BrainClass)
