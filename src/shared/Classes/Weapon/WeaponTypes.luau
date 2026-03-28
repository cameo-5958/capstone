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
export type ComboAttack = {
	AnimationId: AnimationId,
	PowerScale: number,
	MovementLockedUntil: number,
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
	WeaponAbility: AbilityCallback?,
	RightClickAbility: AbilityCallback?,
	ToolTemplate: Tool?,
	ToolInstance: Tool?,

	new: (
		name: string,
		baseDamage: number,
		grantedStats: { [Stat]: number }?,
		weight: number?,
		weaponAbility: AbilityCallback?,
		rightClickAbility: AbilityCallback?,
		weaponId: string?,
		attackProfile: AttackProfile?,
		toolTemplate: Tool?,
		weaponClass: string?,
		attackContext: { [string]: any }?,
		weaponPassive: AttackModifierApplier?
	) -> Weapon,
	SetOwner: (self: Weapon, entity: Entity?) -> Weapon,
	SetToolInstance: (self: Weapon, tool: Tool?) -> Tool?,
	CloneTool: (self: Weapon) -> Tool?,
	GetDamage: (self: Weapon, owner: Entity?) -> number,
	CreateAttackContext: (self: Weapon, target: Entity, comboBaseDamage: number?, owner: Entity?) -> AttackContext,
	ExecuteAttack: (self: Weapon, target: Entity, comboBaseDamage: number?, owner: Entity?) -> AttackContext,
	GetAttackProfile: (self: Weapon) -> AttackProfile,
	GetAttackContext: (self: Weapon) -> { [string]: any },
	UseRightClick: (self: Weapon, owner: Entity?, context: { [string]: any }?) -> boolean,
}

return table.freeze({})


