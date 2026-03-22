--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Brain = {
	-- MovementEngine
	MovementEngine: any,
	Character: Model,
	RootPart: Part,

	-- Current target
	Target: Model?,
	Aggro: boolean,
	RetreatTarget: Model?,
	RetreatUntil: number,
	PendingStrafes: number,

	-- All the neurons this brain has
	Neurons: { Neuron },

	-- Brain constructor and ticking
	new: (any, { Neuron }) -> Brain,
	Tick: (self: Brain, dt: number) -> (),

	-- Different states
	LastEnteredState: number,
	CurrentNeuron: Neuron?,

	-- Go and stop
	Go: (self: Brain) -> (),
	Stop: (self: Brain) -> (),

	-- Utility methods
	HitPlayer: (self: Brain, Model, number) -> boolean,
	GetTargetPlayer: (self: Brain, number) -> Model?,
	Obstruction: (self: Brain, Vector3) -> boolean,
	Delta: (self: Brain, Model) -> Vector3,

	-- Main Thread
	__Thread: RBXScriptConnection?,
}

export type Priority = "Interrupting" | "Core" | "Idle"
export type Neuron = {
	-- Neurons have
	-- - a condition checker
	-- - a "priority type"
	-- - an execution function, including OnEnter, OnExit, and OnUpdate

	-- Conditions
	CanEnter: (self: Neuron) -> boolean,
	CanExit: (self: Neuron) -> boolean,

	-- Priority
	Name: string,
	Priority: Priority,

	-- Execution
	OnEnter: (self: Neuron) -> (),
	OnExit: (self: Neuron) -> (),
	OnUpdate: (self: Neuron, dt: number) -> (),

	-- Any additional attributes
	__Attributes: { any: any },
	GetAttribute: (self: Neuron, attributeName: string) -> any,
	Brain: Brain,
}

return {}
