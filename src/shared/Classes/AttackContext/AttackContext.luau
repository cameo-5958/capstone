--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityType = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local ModifierType = require(ReplicatedStorage.Classes.Modifier.Modifier)

export type AttackType = "Melee" | "Ranged" | "Magic"
export type WeaponType = "Sword" | "Claymore" | "Bow" | "Scroll" | "Staff" | "Shield"

type Entity = EntityType.Entity
type Modifier = ModifierType.Modifier
type ModifierBucket = {
	Base: {[string]: number},
	Additive: {[string]: {Modifier}},
	Multiplicative: {[string]: {Modifier}},
}

export type CombatModifierContext = {
	From: ModifierBucket,
	To: ModifierBucket,
}

export type AttackContext = {
	-- Stores metadata about a single attack

	-- Isolated mechanism; focuses more on stat
	-- boosts, hooks and mechanisms

	-- Only ADDITIONAL effects, most effects are
	-- pulled directly from the character

	AttackType: AttackType,
	WeaponType: WeaponType,

	-- AttackContext environment context
	Distance: number,
	WeaponWeight: number,
	SquadMembersNear: number,

	-- To and From context
	From: Entity,
	To: Entity,

	Modifiers: CombatModifierContext,

	-- Actual "Attack" method
	Attack: (Self: AttackContext) -> (),
}
