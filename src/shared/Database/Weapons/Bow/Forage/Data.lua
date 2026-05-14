local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local WeaponPassive = require(ReplicatedStorage.Classes.Weapon.WeaponPassive)

local function isAnimal(entity): boolean
	return entity["Family"] and entity["Family"] == "Animals"
end

return {
	["Name"] = "Foraging Bow",
	["Type"] = "Bow",
	["Family"] = "Greek",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://108095611101146",

	["BaseDamage"] = 24,
	["__Stats"] = {},
	["Weight"] = 11,
	["WeaponPassive"] = WeaponPassive.new("weapon:bow:forage:affinity", {
		["OnApplyMultipliers"] = function(_, attackContext)
			local target = attackContext.To

			if isAnimal(target) then
				local damageModifiers = attackContext.Modifiers.From.Multiplicative
				damageModifiers["PhysicalDamage"] = damageModifiers["PhysicalDamage"] or {}
				damageModifiers["PhysicalDamage"]["forage_affinity"] =
					Modifier.new("forage_affinity", "Multiplicative", 2, "weapon:bow:forage")
			end
		end,
	}, {
		["Name"] = "Breath of the Forest",
		["Tag"] = "Passive",
		["Desc"] = "Deal twice as much damage against animals.",
		["Values"] = {},
	}),

	["WeaponAbility"] = nil,
	["RightClickAbility"] = nil,

	["Desc"] = "A hunting bow favored by gatherers for its ability to take down small game with ease. Its design allows for quick shots, making it ideal for hunting in dense forests.",
}
