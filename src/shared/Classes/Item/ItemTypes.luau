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
	TargetGroup: "Enemies" | "Players"?,
	IncludeCaster: boolean?,
	Offset: Vector3?,
	Color: Color3?,
	PulseInterval: number?,
	ContactModifierDuration: number?,
	Modifiers: { ItemModifier }?,
	PullSpeed: number?,
	MinPullSpeed: number?,
	MaxResultantSpeed: number?,
	LiftVelocity: number?,
	DeadzoneRadius: number?,
	PullHeight: number?,
}

export type ConsumableDefinition = {
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

export type SerializedConsumableData = {
	Kind: "Consumable",
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

export type InventoryItemDefinition = {
	Id: string,
	Name: string,
	Desc: string,
	Icon: string,
	MaxStack: number,
	SpawnWith: number,
	CanEquip: boolean,
	CanUse: boolean,
	EquipSlotType: string?,
	ModelAssetName: string?,
	InventoryData: { [string]: any }?,
	UseEffects: { [string]: any }?,
}

export type SerializedInventoryItemData = {
	Kind: "Item",
	ItemId: string,
	Name: string,
	Desc: string,
	Icon: string,
	MaxStack: number,
	SpawnWith: number,
	StackKey: string?,
	CanEquip: boolean,
	CanUse: boolean,
	EquipSlotType: string?,
	ModelAssetName: string?,
	InventoryData: { [string]: any },
	UseEffects: { [string]: any }?,
}

export type ItemDefinition = ConsumableDefinition | InventoryItemDefinition
export type SerializedItemData = SerializedConsumableData | SerializedInventoryItemData

return table.freeze({})
