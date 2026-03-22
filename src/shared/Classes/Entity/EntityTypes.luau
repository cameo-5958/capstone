--!strict

-- Define the class's type
export type Stat =
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

export type StatBlock = { [Stat]: number }

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
	__Stats: StatBlock,
	__Animations: { [string]: string },
	__Buffs: { [string]: any },
	__Components: {
		EquippedIndex: number?,
		ToolbarWeapons: { any? },
	},

	-- States
	__Alive: boolean,

	-- Constructor
	new: (Model, string) -> Entity,
	Inflate: (ent: Entity) -> Entity,

	-- Stat Methods
	GetStat: (self: Entity, stat: Stat) -> number,
	SetStat: (self: Entity, stat: Stat, to: number) -> number,
	ModifyStat: (self: Entity, stat: Stat, delta: number) -> number,
	IsAlive: (self: Entity) -> boolean,
	GetEquippedWeapon: (self: Entity) -> any?,
	GetEquippedIndex: (self: Entity) -> number?,
	SetEquippedIndex: (self: Entity, index: number?) -> number?,
	ClearEquippedWeapon: (self: Entity) -> any?,
	GetToolbarWeapon: (self: Entity, slot: number) -> any?,
	SetToolbarWeapon: (self: Entity, slot: number, weapon: any?) -> any?,
	GetToolbarWeapons: (self: Entity) -> { any? },

	-- Doing damage
	ApplyDamage: (self: Entity, damage: number, target: Entity) -> (),
	TakeDamage: (self: Entity, damage: number, source: Entity) -> (),
}

-- Return the class
return {}
