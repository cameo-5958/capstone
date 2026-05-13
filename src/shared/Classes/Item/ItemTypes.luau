--!strict

local EntityTypes = require(script.Parent.Parent.Entity.EntityTypes)
local ModifierType = require(script.Parent.Parent.Modifier.ModifierType)

export type Stat = EntityTypes.Stat
export type ModifierKind = ModifierType.ModifierKind

export type ItemEffectFlag = "AffectOverTime" | "OnContact" | "SelfTarget"
export type ItemEffectKind =
	"Heal"
	| "HealOverTime"
	| "DamageOverTime"
	| "Tornado"
	| "ApplyModifierOnContact"
	| "SelfBuff"
	| "FlagBoost"

export type ItemModifier = {
	Stat: Stat,
	ModifierType: ModifierKind,
	Value: number,
}

export type ItemEffect = {
	Kind: ItemEffectKind,
	Flags: { ItemEffectFlag }?,
	Amount: number?,
	AmountPerTick: number?,
	HealPercentPerTick: number?,
	DamagePerTick: number?,
	Duration: number?,
	TickRate: number?,
	Range: number?,
	Radius: number?,
	Target: "Self" | "NearestEnemy" | "EnemiesInRadius"?,
	Offset: Vector3?,
	Color: Color3?,
	PulseInterval: number?,
	ContactModifierDuration: number?,
	Modifiers: { ItemModifier }?,
}

export type ItemDefinition = {
	Id: string,
	Name: string,
	Desc: string,
	Icon: string,
	MaxStack: number,
	SpawnWith: number,
	StackKey: string?,
	InventoryData: { [string]: any }?,
	Effects: { ItemEffect },
}

export type SerializedItemData = {
	Kind: "Item",
	ItemId: string,
	Name: string,
	Desc: string,
	Icon: string,
	MaxStack: number,
	SpawnWith: number,
	StackKey: string,
	InventoryData: { [string]: any },
	Effects: { ItemEffect },
}

return table.freeze({})
