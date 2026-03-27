--!strict

local ModifierType = require(script.Parent.Parent.Modifier.ModifierType)
local Signal = require(script.Parent.Parent.Modifier.Signal)
local StatModule = require(script.Parent.Parent.Modifier.Stat)
local StatBlockModule = require(script.Parent.Parent.Modifier.StatBlock)
local AttackModifierApplierType = require(script.Parent.Parent.Attack.AttackModifierApplier)

export type Stat =
	"Health"
	| "MaxHealth"
	| "Defense"
	| "Strength"
	| "CritRate"
	| "CritDamage"
	| "Intelligence"
	| "PhysicalAttack"
	| "MagicalAttack"
	| "PhysicalDamage"
	| "MagicDamage"
	| "Speed"

export type StatBlock = { [Stat]: number }
export type Modifier = ModifierType.Modifier
export type ModifierKind = ModifierType.ModifierKind
export type ModifierHandle = StatBlockModule.ModifierHandle
export type StatSignal = Signal.Signal
export type RuntimeStat = StatModule.Stat
export type RuntimeStatBlock = StatBlockModule.StatBlock
export type AttackModifierApplier = AttackModifierApplierType.AttackModifierApplier

export type Entity = {
	UUID: string,
	Name: string,
	Family: string,
	Level: number,
	__ScaledLevel: number,

	Character: Model,
	RootPart: BasePart,

	-- Replicated snapshot of final stat values.
	-- Runtime modifier state lives outside the raw entity table so
	-- the entity can still be sent across remotes safely.
	__Stats: StatBlock,
	__Animations: { [string]: string },
	__Buffs: { [string]: { ModifierHandle } },
	__AttackModifierAppliers: { AttackModifierApplier },
	__Components: {
		EquippedIndex: number?,
		ToolbarWeapons: { any? },
	},

	__Alive: boolean,

	new: (Model, string) -> Entity,
	Inflate: (ent: Entity) -> Entity,

	GetStat: (self: Entity, stat: Stat) -> number,
	GetBaseStat: (self: Entity, stat: Stat) -> number,
	SetStat: (self: Entity, stat: Stat, to: number) -> number,
	ModifyStat: (self: Entity, stat: Stat, delta: number) -> number,
	SyncCharacterStats: (self: Entity) -> (),
	AddModifier: (self: Entity, stat: Stat, modifier: Modifier) -> ModifierHandle,
	RemoveModifier: (self: Entity, stat: Stat, modifierId: string) -> boolean,
	RemoveModifierHandle: (self: Entity, handle: ModifierHandle?) -> boolean,
	RemoveModifiersFromSource: (self: Entity, source: string) -> number,
	RegisterBuffHandles: (self: Entity, source: string, handles: { ModifierHandle }) -> (),
	ClearBuffSource: (self: Entity, source: string) -> number,
	AddAttackModifierApplier: (self: Entity, applier: AttackModifierApplier) -> AttackModifierApplier,
	RemoveAttackModifierApplier: (self: Entity, applier: AttackModifierApplier) -> boolean,
	GetAttackModifierAppliers: (self: Entity) -> { AttackModifierApplier },
	TriggerApply: (self: Entity, attackContext: any) -> (),
	TriggerOnApplyMultipliers: (self: Entity, attackContext: any) -> (),
	TriggerOnCritRoll: (self: Entity, attackContext: any) -> (),
	TriggerOnAttackEnemy: (self: Entity, attackContext: any) -> (),
	TriggerOnDefeatEnemy: (self: Entity, attackContext: any) -> (),
	TriggerOnOncomingHit: (self: Entity, attackContext: any) -> (),
	TriggerOnShieldBlock: (self: Entity, attackContext: any) -> (),
	TriggerProcureData: (self: Entity, attackContext: any) -> (),
	TriggerOnHitSuccess: (self: Entity, attackContext: any) -> (),
	TriggerOnProjectileExpire: (self: Entity, attackContext: any) -> (),
	TriggerOnWeaponSwap: (self: Entity, attackContext: any) -> (),
	GetStatChangedSignal: (self: Entity, stat: Stat) -> StatSignal,
	IsAlive: (self: Entity) -> boolean,
	GetEquippedWeapon: (self: Entity) -> any?,
	GetEquippedIndex: (self: Entity) -> number?,
	SetEquippedIndex: (self: Entity, index: number?) -> number?,
	ClearEquippedWeapon: (self: Entity) -> any?,
	GetToolbarWeapon: (self: Entity, slot: number) -> any?,
	SetToolbarWeapon: (self: Entity, slot: number, weapon: any?) -> any?,
	GetToolbarWeapons: (self: Entity) -> { any? },

	ApplyDamage: (self: Entity, damage: number, target: Entity) -> (),
	TakeDamage: (self: Entity, damage: number, source: Entity) -> (),
}

return {}
