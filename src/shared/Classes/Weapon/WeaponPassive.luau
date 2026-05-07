--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackModifierApplierModule = require(ReplicatedStorage.Classes.Attack.AttackModifierApplier)

type AttackModifierApplier = AttackModifierApplierModule.AttackModifierApplier

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
	Metadata: PassiveMetadata,
}

local WeaponPassive = {}

local function normalizeMetadata(id: string, metadata: PassiveMetadata?): PassiveMetadata
	local normalized = table.clone(metadata or {}) :: PassiveMetadata
	normalized.Id = normalized.Id or id
	normalized.Kind = normalized.Kind or "Passive"
	normalized.Tag = normalized.Tag or "Passive"
	return normalized
end

function WeaponPassive.new(
	id: string?,
	hooks: { [string]: any }?,
	metadata: PassiveMetadata?,
	attributes: { [string]: any }?,
	components: { [string]: any }?
): WeaponPassiveDefinition
	local applier = AttackModifierApplierModule.new(id, hooks, attributes, components)

	return {
		Applier = applier,
		Metadata = normalizeMetadata(applier.Id, metadata),
	}
end

function WeaponPassive.from(applier: AttackModifierApplier, metadata: PassiveMetadata?): WeaponPassiveDefinition
	return {
		Applier = applier,
		Metadata = normalizeMetadata(applier.Id, metadata),
	}
end

return table.freeze(WeaponPassive)
