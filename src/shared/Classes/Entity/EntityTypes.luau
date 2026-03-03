--!strict

-- Import BrainTypes

-- Define the class's type
type Stat =
	"Health"
	| "MaxHealth"
	| "Defense"
	| "TrueDefense"
	| "Resistance" -- EHP
	| "Strength"
	| "CritRate"
	| "CritDamage" -- Multiplicative, Phys DPS
	| "Intelligence" -- Exponential, Magical DPS
	| "PhysicalAttack"
	| "MagicalAttack"
	| "Speed" -- Movement SPeed

export type Entity = {
	-- ENTITY
	-- Base Metadata
	UUID: string,
	Name: string,
	Family: string,
	Level: number,
	__ScaledLevel: number,

	-- Models
	Character: Model,
	RootPart: BasePart,

	-- Stats
	__Stats: { Stat: number },
	__Buffs: {},

	-- States
	__Alive: boolean,

	-- Constructor
	new: (Model, string) -> Entity,
	Inflate: (ent: Entity) -> Entity,

	-- Stat Methods
	GetStat: (self: Entity, stat: Stat) -> number,
	SetStat: (self: Entity, stat: Stat, to: number) -> number,
	IsAlive: (self: Entity) -> boolean,

	-- Doing damage
	ApplyDamage: (self: Entity, damage: number, target: Entity) -> (),
	TakeDamage: (self: Entity, damage: number, source: Entity) -> (),

	-- Animation
	Animate: (self: Entity, animId: string) -> (),
}

-- Return the class
return {}
