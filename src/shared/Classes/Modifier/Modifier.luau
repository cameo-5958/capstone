--!strict

local ModifierType = require(script.Parent.ModifierType)

export type Modifier = ModifierType.Modifier
export type ModifierKind = ModifierType.ModifierKind

local Modifier = {}
Modifier.__index = Modifier

--[[
	Create a modifier payload for Entity:AddModifier(...).

	Common usage:
		local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
		entity:AddModifier("Speed", Modifier.new(
			"class:rogue:speed",
			"FinalAdditive",
			0.15,
			"class:rogue"
		))
]]
function Modifier.new(id: string, modifierType: ModifierKind, value: number, source: string?): Modifier
	return {
		Id = id,
		Type = modifierType,
		Value = value,
		Source = source,
	}
end

return table.freeze(Modifier)
