local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local WeaponPassive = require(ReplicatedStorage.Classes.Weapon.WeaponPassive)

return {
	["Name"] = "Last Strike",
	["Type"] = "Sword",
	["Family"] = "Unbound",
	["Rarity"] = "EXALTED",

	["BaseDamage"] = 185,
	["__Stats"] = {
		["Strength"] = 100,
		["CritDamage"] = 100,
	},
	["Weight"] = 9,
	["WeaponPassive"] = WeaponPassive.new("weapon:unbound:last_strike:execute", {
		["OnApplyMultipliers"] = function(_, attackContext)
			local target = attackContext.To
			if not target then
				return
			end

			local maxHealth = target:GetStat("MaxHealth")
			if maxHealth <= 0 then
				return
			end

			local currentHealth = target:GetStat("Health")
			if currentHealth > (maxHealth * 0.3) then
				return
			end

			local damageModifiers = attackContext.Modifiers.From.BaseFlat
			damageModifiers["PhysicalDamage"] = damageModifiers["PhysicalDamage"] or {}
			damageModifiers["PhysicalDamage"]["last_strike_execute"] =
				Modifier.new("last_strike_execute", "BaseFlat", 0.3, "weapon:unbound:last_strike")
		end,
	}, {
		["Name"] = "Final Breath",
		["Tag"] = "Passive",
		["Desc"] = "Deal bonus physical damage to enemies below 30% health.",
		["Values"] = {
			["HealthThreshold"] = 0.3,
			["BonusPhysicalDamage"] = 0.3,
		},
	}),

	["WeaponAbility"] = nil,
	["RightClickAbility"] = nil,

	["Desc"] = "An exalted blade awaiting its final tuning.",
}
