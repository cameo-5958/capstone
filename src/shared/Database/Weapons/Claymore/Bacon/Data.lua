local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponPassive = require(ReplicatedStorage.Classes.Weapon.WeaponPassive)

return {
	["Name"] = "Bacon Punch",
	["Type"] = "Claymore",
	["Family"] = "Greek",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://127156946366798",

	["BaseDamage"] = 22,
	["__Stats"] = {},
	["Weight"] = 11,
	["WeaponPassive"] = WeaponPassive.new("weapon:claymore:bacon:chomp", {
		["OnApplyMultipliers"] = function(_, attackContext)
			local attacker = attackContext.From
			if not attacker then
				return
			end

			local maxHealth = attacker:GetStat("MaxHealth")
			local currentHealth = attacker:GetStat("Health")
			attacker:SetStat("Health", math.min(maxHealth, currentHealth + 2))
		end,
	}, {
		["Name"] = "Chomp",
		["Tag"] = "Passive",
		["Desc"] = "Heal 2 health per hit.",
		["Values"] = {},
	}),
	["WeaponAbility"] = nil,
	["RightClickAbility"] = nil,

	["Desc"] = "The Sword of a player who always seems to be hungry. Its swing has a potent, unexplainable magic.",
}
