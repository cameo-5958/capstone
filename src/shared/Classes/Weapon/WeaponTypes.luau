--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityTypes.Entity
type Stat = EntityTypes.Stat

export type AbilityCallback = (self: any, owner: Entity, context: { [string]: any }?) -> ()
export type AttackProfile = {
	AnimationId: string,
	Windup: number,
	ActiveDuration: number,
	Recovery: number,
	Cooldown: number,
	HitReset: number,
	HitboxSize: Vector3,
	HitboxOffset: CFrame,
}

export type Weapon = {
	UUID: string,
	Name: string,
	WeaponId: string,
	Class: string,
	AttackContext: { [string]: any },
	BaseDamage: number,
	GrantedStats: { [Stat]: number },
	Weight: number,
	AttackProfile: AttackProfile,
	Owner: Entity?,
	RightClickAbility: AbilityCallback?,
	ToolTemplate: Tool?,
	ToolInstance: Tool?,

	new: (
		name: string,
		baseDamage: number,
		grantedStats: { [Stat]: number }?,
		rightClickAbility: AbilityCallback?,
		weaponId: string?,
		attackProfile: AttackProfile?,
		toolTemplate: Tool?,
		weaponClass: string?,
		attackContext: { [string]: any }?
	) -> Weapon,
	SetOwner: (self: Weapon, entity: Entity?) -> Weapon,
	SetToolInstance: (self: Weapon, tool: Tool?) -> Tool?,
	CloneTool: (self: Weapon) -> Tool?,
	GetDamage: (self: Weapon, owner: Entity?) -> number,
	GetAttackProfile: (self: Weapon) -> AttackProfile,
	GetAttackContext: (self: Weapon) -> { [string]: any },
	UseRightClick: (self: Weapon, owner: Entity?, context: { [string]: any }?) -> boolean,
}

return table.freeze({})
