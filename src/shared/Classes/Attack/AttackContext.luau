--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EntityType = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local ModifierType = require(ReplicatedStorage.Classes.Modifier.Modifier)
local StatBlock = require(ReplicatedStorage.Classes.Modifier.StatBlock)

export type AttackType = "Melee" | "Ranged" | "Magic"
export type WeaponType = "Sword" | "Claymore" | "Bow" | "Scroll" | "Staff" | "Shield"
export type SpellType = "Amplification" | "Healing" | "Damage" | "Tanking"

type Entity = EntityType.Entity
type Modifier = ModifierType.Modifier
type ModifierBucket = {
	Base: { [string]: number },
	BaseFlat: { [string]: { Modifier } },
	Additive: { [string]: { Modifier } },
	Multiplicative: { [string]: { Modifier } },
	FinalFlat: { [string]: { Modifier } },
}
type StatBlock = StatBlock.StatBlock

export type CombatModifierContext = {
	From: ModifierBucket,
	To: ModifierBucket,
}

export type FinalStatContext = {
	From: { [string]: number },
	To: { [string]: number },
}

export type AttackContext = {
	-- Stores metadata about a single attack

	-- Isolated mechanism; focuses more on stat
	-- boosts, hooks and mechanisms

	-- Only ADDITIONAL effects, most effects are
	-- pulled directly from the character

	AttackType: AttackType,
	WeaponType: WeaponType,
	SpellType: SpellType,
	ManaCost: number, -- Spells
	StaminaCost: number, -- Melee
	Range: number, -- Archer

	-- AttackContext environment context
	Distance: number,
	WeaponWeight: number,
	SquadMembersNear: number,

	-- To and From context
	From: Entity,
	To: Entity,
	BaseDamage: number,

	Modifiers: CombatModifierContext,
	FinalStats: FinalStatContext,

	-- Actual "Attack" method
	new: (from: Entity, to: Entity) -> AttackContext,
	Attack: (Self: AttackContext) -> (),
}

local function CreateModifierBucket(entity: Entity): ModifierBucket
	local baseStats: { [any]: number } = table.clone(entity.__Stats)

	return {
		Base = baseStats,
		BaseFlat = {},
		Additive = {},
		Multiplicative = {},
		FinalFlat = {},
	}
end

local AttackContext = {}
AttackContext.__index = AttackContext

function AttackContext.new(from: Entity, to: Entity): AttackContext
	local self = setmetatable({}, AttackContext)

	self.AttackType = "Melee"
	self.WeaponType = "Sword"
	self.SpellType = "Damage"
	self.ManaCost = 0
	self.StaminaCost = 0
	self.Range = 0
	self.Distance = 0
	self.WeaponWeight = 0
	self.SquadMembersNear = 0
	self.From = from
	self.To = to
	self.BaseDamage = 0
	self.Modifiers = {
		From = CreateModifierBucket(from),
		To = CreateModifierBucket(to),
	}
	self.FinalStats = {
		From = {},
		To = {},
	}

	return (self :: any) :: AttackContext
end

function AttackContext.Attack(self: AttackContext): ()
	error("AttackContext.Attack must be implemented by subclasses")
end

return table.freeze(AttackContext)
