local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local WeaponPassive = require(ReplicatedStorage.Classes.Weapon.WeaponPassive)

return {
	["Name"] = "Athena",
	["Type"] = "Sword",
	["Family"] = "Power",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://132289183902381",

	["BaseDamage"] = 75,
	["__Stats"] = {
		["CritRate"] = 1,
	},
	["Weight"] = 11,
	["WeaponPassive"] = WeaponPassive.new("weapon:sword:wisdom:ingenuity", {
		["Apply"] = function(_, attackContext)
			local damageModifiers = attackContext.Modifiers.From.Multiplicative
			for _, stat in ipairs({ "Strength", "CritDamage", "Defense" }) do
				damageModifiers[stat] = damageModifiers[stat] or {}
				damageModifiers[stat]["wisdom_ingenuity"] =
					Modifier.new("wisdom_ingenuity", "Multiplicative", 1.25, "weapon:sword:wisdom")
			end
		end,
	}, {
		["Name"] = "Ingenuity",
		["Tag"] = "Passive",
		["Desc"] = "Massively increase many stats by 1.25x.",
		["Values"] = {},
	}),

	["WeaponAbility"] = nil,
	["RightClickAbility"] = nil,

	["Desc"] = "A powerful blade that embodies the wisdom of the original goddess of wisdom, granting immense power to those who can wield it.",
}
