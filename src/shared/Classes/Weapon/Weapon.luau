--!strict
-- Weapon.luau: represents a weapon and its data for attacking

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackModifierApplierModule = require(ReplicatedStorage.Classes.Attack.AttackModifierApplier)
local AttackContextModule = require(ReplicatedStorage.Classes.Attack.AttackContext)
local Damage = require(ReplicatedStorage.Classes.Attack.Damage)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local WeaponTypes = require(script.Parent.WeaponTypes)

type AttackModifierApplier = AttackModifierApplierModule.AttackModifierApplier
type AttackContext = AttackContextModule.AttackContext
type Entity = EntityTypes.Entity
type Stat = EntityTypes.Stat

export type AbilityCallback = WeaponTypes.AbilityCallback
export type AnimationId = WeaponTypes.AnimationId
export type AttackProfile = WeaponTypes.AttackProfile
export type ComboAttack = WeaponTypes.ComboAttack
export type ComboDefinition = WeaponTypes.ComboDefinition
export type ComboSet = WeaponTypes.ComboSet
export type Weapon = WeaponTypes.Weapon

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
	weight: number?,
	weaponAbility: AbilityCallback?,
	rightClickAbility: AbilityCallback?,
	weaponId: string?,
	attackProfile: AttackProfile?,
	toolTemplate: Tool?,
	weaponClass: string?,
	attackContext: { [string]: any }?,
	weaponPassive: AttackModifierApplier?
): Weapon
	local self = setmetatable({}, Weapon)

	self.UUID = HttpService:GenerateGUID(false)
	self.Name = name
	self.WeaponId = weaponId or name
	self.Class = weaponClass or "Sword"
	self.Type = self.Class
	self.AttackContext = table.clone(attackContext or {})
	self.BaseDamage = baseDamage
	self.Damage = Damage
	self.GrantedStats = table.clone(grantedStats or {})
	self.Weight = weight or 0
	self.AttackProfile = MergeAttackProfile(attackProfile)
	self.Owner = nil
	self.WeaponPassive = weaponPassive
	self.WeaponAbility = weaponAbility or rightClickAbility
	self.RightClickAbility = self.WeaponAbility
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
	return self.BaseDamage
end

function Weapon.CreateAttackContext(self: Weapon, target: Entity, comboBaseDamage: number?, owner: Entity?): AttackContext
	local wielder = owner or self.Owner
	assert(wielder ~= nil, "Weapon.CreateAttackContext requires an owner")

	local attackContextData = self:GetAttackContext()
	local context = self.Damage.Build(wielder, target, self.BaseDamage * (comboBaseDamage or 1))
	context.WeaponType = self.Type :: any
	context.WeaponWeight = self.Weight
	context.ManaCost = attackContextData.ManaCost or 0
	context.StaminaCost = attackContextData.StaminaCost or 0
	context.Range = attackContextData.Range or attackContextData.SwingRange or 0

	if self.Type == "Bow" then
		context.AttackType = "Ranged"
	elseif self.Type == "Scroll" or self.Type == "Staff" then
		context.AttackType = "Magic"
	else
		context.AttackType = "Melee"
	end

	return context
end

function Weapon.ExecuteAttack(self: Weapon, target: Entity, comboBaseDamage: number?, owner: Entity?): AttackContext
	local context = self:CreateAttackContext(target, comboBaseDamage, owner)
	context:Attack()
	return context
end

--[[
	Weapon metadata should stay data-only.
	If a future weapon needs to grant stats on equip, do not mutate
	entity.__Stats directly. Instead, call:

		local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
		local handle = entity:AddModifier("Strength", Modifier.new(
			"weapon:<weaponId>:strength",
			"BaseFlat",
			5,
			"weapon:<weaponId>"
		))

	Then remove it later with either:
		entity:RemoveModifierHandle(handle)
	or:
		entity:RemoveModifiersFromSource("weapon:<weaponId>")
]]
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

function Weapon.GetAttackContext(self: Weapon): { [string]: any }
	return table.clone(self.AttackContext)
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
