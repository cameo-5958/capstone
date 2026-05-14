local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackModifierApplier = require(ReplicatedStorage.Classes.Attack.AttackModifierApplier)
local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local WeaponPassive = require(ReplicatedStorage.Classes.Weapon.WeaponPassive)

local BLOODLUST_ABILITY_DURATION = 10
local BLOODLUST_ABILITY_HEALTH_COST_RATIO = 0.5

return {
	["Name"] = "Ares",
	["Type"] = "Sword",
	["Family"] = "Power",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://116987837030313",

	["BaseDamage"] = 75,
	["__Stats"] = {
		["CritDamage"] = 150,
		["Strength"] = 150,
	},
	["Weight"] = 11,
	["WeaponPassive"] = WeaponPassive.new("weapon:sword:war:bloodlust", {
		["OnApplyMultipliers"] = function(_, attackContext)
			local me = attackContext.From
			if not me then
				return
			end

			local maxHealth = me:GetStat("MaxHealth")
			if maxHealth <= 0 then
				return
			end

			local currentHealth = me:GetStat("Health")
			local percentage = currentHealth / maxHealth

			local damageModifiers = attackContext.Modifiers.From.Additive
			damageModifiers["PhysicalDamage"] = damageModifiers["PhysicalDamage"] or {}
			damageModifiers["PhysicalDamage"]["war_bloodlust"] =
				Modifier.new("war_bloodlust", "FinalAdditive", percentage, "weapon:sword:war")
		end,
	}, {
		["Name"] = "Bloodlust",
		["Tag"] = "Passive",
		["Desc"] = "Deal 1% more damage per percentage of health you've lost.",
	}),

	["WeaponAbility"] = nil,
	["RightClickAbility"] = {
		Execute = function(_, owner, _)
			local maxHealth = owner:GetStat("MaxHealth")
			if maxHealth <= 0 then
				return
			end

			local healthCost = maxHealth * BLOODLUST_ABILITY_HEALTH_COST_RATIO
			local currentHealth = owner:GetStat("Health")
			if currentHealth <= healthCost then
				return
			end

			owner:SetStat("Health", currentHealth - healthCost)

			local modifierId = string.format("weapon:sword:war:rightclick:%s", HttpService:GenerateGUID(false))
			owner:AddAttackModifier(AttackModifierApplier.new(modifierId, {
				["OnApplyMultipliers"] = function(_, attackContext)
					local damageModifiers = attackContext.Modifiers.From.Multiplicative
					damageModifiers["PhysicalDamage"] = damageModifiers["PhysicalDamage"] or {}
					damageModifiers["PhysicalDamage"]["war_bloodlust_ability"] =
						Modifier.new("war_bloodlust_ability", "Multiplicative", 2, "weapon:sword:war:rightclick")
				end,
			}))

			task.delay(BLOODLUST_ABILITY_DURATION, function()
				owner:RemoveAttackModifierById(modifierId)
			end)
		end,
	},

	["Desc"] = "A blade of the original god of war, whos suffering can be embodied to immensely increase your damage.",
}
