--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackModifierApplierModule = require(ReplicatedStorage.Classes.Attack.AttackModifierApplier)
local AttackContextModule = require(ReplicatedStorage.Classes.Attack.AttackContext)
local DamageModule = require(ReplicatedStorage.Classes.Attack.Damage)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityTypes.Entity
type Stat = EntityTypes.Stat
type AttackModifierApplier = AttackModifierApplierModule.AttackModifierApplier
type AttackContext = AttackContextModule.AttackContext
type Damage = DamageModule.Damage

export type AbilityCallback = (self: any, owner: Entity, context: { [string]: any }?) -> ()
export type AbilityMetadata = {
	Id: string?,
	Kind: string?,
	Tag: string?,
	Name: string?,
	Title: string?,
	Desc: string?,
	Description: string?,
	Values: { [string]: any }?,
}
export type WeaponAbilityDefinition = {
	Execute: AbilityCallback,
	Cooldown: number?,
	Metadata: AbilityMetadata | { AbilityMetadata }?,
}
export type PassiveMetadata = {
	Id: string?,
	Kind: string?,
	Tag: string?,
	Name: string?,
	Title: string?,
	Desc: string?,
	Description: string?,
	Values: { [string]: any }?,
}
export type WeaponPassiveDefinition = {
	Applier: AttackModifierApplier,
	Metadata: PassiveMetadata | { PassiveMetadata },
}
export type WeaponPassiveInput = AttackModifierApplier | WeaponPassiveDefinition
export type WeaponAbilityInput = AbilityCallback | WeaponAbilityDefinition
export type AnimationId = string | { string }
export type AttackProfile = {
	AnimationId: AnimationId,
	Windup: number,
	ActiveDuration: number,
	Recovery: number,
	Cooldown: number,
	HitReset: number,
	HitboxSize: Vector3,
	HitboxOffset: CFrame,
}
export type ComboAttackProfile = {
	AnimationId: AnimationId?,
	Windup: number?,
	ActiveDuration: number?,
	Recovery: number?,
	Cooldown: number?,
	HitReset: number?,
	HitboxSize: Vector3?,
	HitboxOffset: CFrame?,
}
export type ComboAttackContext = {
	SightRange: number?,
	SwingRange: number?,
	MaxDashRange: number?,
	LungeDuration: number?,
	LockDuration: number?,
	MovementLockDuration: number?,
	ActionLockDuration: number?,
	ManaCost: number?,
	StaminaCost: number?,
	Range: number?,
}
export type HitWindow = {
	Delay: number,
	Duration: number?,
	AttackContext: ComboAttackContext?,
	AttackProfile: ComboAttackProfile?,
}
export type ComboAttack = {
	AnimationId: AnimationId,
	PowerScale: number,
	MovementLockedUntil: number,
	IsHeavy: boolean?,
	DoesKnockback: boolean?,
	NoStamina: boolean?,
	AttackContext: ComboAttackContext?,
	AttackProfile: ComboAttackProfile?,
	HitWindows: { HitWindow }?,
}
export type ComboDefinition = {
	Id: string,
	Attacks: { ComboAttack },
}
export type ComboSet = {
	ExpireAfter: number,
	DefaultCombo: string?,
	Combos: { [string]: ComboDefinition },
}

export type Weapon = {
	UUID: string,
	Name: string,
	WeaponId: string,
	Rarity: string,
	Class: string,
	Type: string,
	AttackContext: { [string]: any },
	BaseDamage: number,
	Damage: Damage,
	GrantedStats: { [Stat]: number },
	Weight: number,
	AttackProfile: AttackProfile,
	Owner: Entity?,
	WeaponPassive: AttackModifierApplier?,
	PassiveDetails: { PassiveMetadata },
	WeaponAbility: AbilityCallback?,
	RightClickAbility: AbilityCallback?,
	AbilityCooldown: number?,
	VisualTemplate: Instance?,
	VisualInstance: Model?,
	GripCFrame: CFrame,
	Cooldown: number?,
	LastUsed: number?,

	new: (
		name: string,
		baseDamage: number,
		grantedStats: { [Stat]: number }?,
		weight: number?,
		weaponAbility: WeaponAbilityInput?,
		rightClickAbility: WeaponAbilityInput?,
		weaponId: string?,
		attackProfile: AttackProfile?,
		visualTemplate: Instance?,
		gripCFrame: CFrame?,
		weaponClass: string?,
		attackContext: { [string]: any }?,
		weaponPassive: WeaponPassiveInput?,
		rarity: string?,
		passiveDetails: { PassiveMetadata }?,
		cooldown: number?
	) -> Weapon,
	SetOwner: (self: Weapon, entity: Entity?) -> Weapon,
	SetVisualInstance: (self: Weapon, model: Model?) -> Model?,
	GetDamage: (self: Weapon, owner: Entity?) -> number,
	CreateAttackContext: (
		self: Weapon,
		target: Entity,
		comboBaseDamage: number?,
		owner: Entity?,
		attackFlags: { IsHeavy: boolean?, DoesKnockback: boolean?, AttackContext: ComboAttackContext? }?
	) -> AttackContext,
	ExecuteAttack: (
		self: Weapon,
		target: Entity,
		comboBaseDamage: number?,
		owner: Entity?,
		attackFlags: { IsHeavy: boolean?, DoesKnockback: boolean?, AttackContext: ComboAttackContext? }?
	) -> AttackContext,
	GetAttackProfile: (self: Weapon) -> AttackProfile,
	GetAttackContext: (self: Weapon) -> { [string]: any },
	UseRightClick: (self: Weapon, owner: Entity?, context: { [string]: any }?) -> boolean,
}

return table.freeze({})

