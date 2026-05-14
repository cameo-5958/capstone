local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponPassive = require(ReplicatedStorage.Classes.Weapon.WeaponPassive)

return {
	["Name"] = "Plundering Cutlass",
	["Type"] = "Sword",
	["Family"] = "Pirate",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://107183617729624",

	["BaseDamage"] = 12,
	["__Stats"] = {
		["CritDamage"] = 15,
	},
	["Weight"] = 11,
	["WeaponPassive"] = WeaponPassive.new("weapon:sword:pirate:plunder", {
		["OnDefeatEnemy"] = function(_, attackContext)
			local attacker = attackContext.From
			if not attacker or not attacker.Character then
				return
			end

			local player = Players:GetPlayerFromCharacter(attacker.Character)
			if not player then
				return
			end

			local inventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
			inventoryServiceServer.AddStackableItem(player, "Currency", "Gold", {
				DisplayName = "Gold",
			}, 1)
		end,
	}, {
		["Name"] = "Plunder",
		["Tag"] = "Passive",
		["Desc"] = "Defeating an enemy grants 1 extra coin.",
		["Values"] = {},
	}),

	["WeaponAbility"] = nil,
	["RightClickAbility"] = nil,

	["Desc"] = "The cutlass of a pirate, used for plundering and pillaging. It has a chance to drop extra coins when hitting enemies.",
}
