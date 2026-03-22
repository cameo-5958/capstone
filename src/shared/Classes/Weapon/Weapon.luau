--!strict
-- Weapon.luau: represents a weapon and its data for attacking

local HttpService = game:GetService("HttpService")
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
	BaseDamage: number,
	GrantedStats: { [Stat]: number },
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
		toolTemplate: Tool?
	) -> Weapon,
	SetOwner: (self: Weapon, entity: Entity?) -> Weapon,
	SetToolInstance: (self: Weapon, tool: Tool?) -> Tool?,
	CloneTool: (self: Weapon) -> Tool?,
	GetDamage: (self: Weapon, owner: Entity?) -> number,
	GetAttackProfile: (self: Weapon) -> AttackProfile,
	UseRightClick: (self: Weapon, owner: Entity?, context: { [string]: any }?) -> boolean,
}

local Weapon = {}
Weapon.__index = Weapon

local DEFAULT_ATTACK_PROFILE: AttackProfile = {
	AnimationId = "",
	Windup = 0.12,
	ActiveDuration = 0.16,
	Recovery = 0.22,
	Cooldown = 0.55,
	HitReset = 0.12,
	HitboxSize = Vector3.new(5, 5, 6),
	HitboxOffset = CFrame.new(0, 0, -3.5),
}

local function MergeAttackProfile(profile: AttackProfile?): AttackProfile
	local merged = table.clone(DEFAULT_ATTACK_PROFILE) :: any
	if not profile then
		return merged
	end

	for key, value in pairs(profile) do
		merged[key] = value
	end

	return merged
end

function Weapon.new(
	name: string,
	baseDamage: number,
	grantedStats: { [Stat]: number }?,
	rightClickAbility: AbilityCallback?,
	weaponId: string?,
	attackProfile: AttackProfile?,
	toolTemplate: Tool?
): Weapon
	local self = setmetatable({}, Weapon)

	self.UUID = HttpService:GenerateGUID(false)
	self.Name = name
	self.WeaponId = weaponId or name
	self.BaseDamage = baseDamage
	self.GrantedStats = table.clone(grantedStats or {})
	self.AttackProfile = MergeAttackProfile(attackProfile)
	self.Owner = nil
	self.RightClickAbility = rightClickAbility
	self.ToolTemplate = toolTemplate
	self.ToolInstance = nil

	return (self :: any) :: Weapon
end

function Weapon.SetOwner(self: Weapon, entity: Entity?): Weapon
	self.Owner = entity
	return self
end

function Weapon.SetToolInstance(self: Weapon, tool: Tool?): Tool?
	self.ToolInstance = tool
	return tool
end

function Weapon.CloneTool(self: Weapon): Tool?
	if not self.ToolTemplate then
		return nil
	end

	local clone = self.ToolTemplate:Clone()
	clone.Name = self.Name
	return clone
end

function Weapon.GetDamage(self: Weapon, owner: Entity?): number
	local wielder = owner or self.Owner
	if not wielder then
		return self.BaseDamage
	end

	return self.BaseDamage + wielder:GetStat("PhysicalAttack") + wielder:GetStat("Strength")
end

function Weapon.GetAttackProfile(self: Weapon): AttackProfile
	local profile = self.AttackProfile

	return {
		AnimationId = profile.AnimationId,
		Windup = profile.Windup,
		ActiveDuration = profile.ActiveDuration,
		Recovery = profile.Recovery,
		Cooldown = profile.Cooldown,
		HitReset = profile.HitReset,
		HitboxSize = profile.HitboxSize,
		HitboxOffset = profile.HitboxOffset,
	}
end

function Weapon.UseRightClick(self: Weapon, owner: Entity?, context: { [string]: any }?): boolean
	local wielder = owner or self.Owner
	if not wielder or not self.RightClickAbility then
		return false
	end

	self.RightClickAbility(self, wielder, context or {})
	return true
end

return Weapon
