local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local WeaponPassive = require(ReplicatedStorage.Classes.Weapon.WeaponPassive)

local DROP_SCATTER_RADIUS = 2.25

local InventoryItemRegistry = nil :: any
local ItemDropServiceServer = nil :: any

local function isAnimal(entity): boolean
	return entity["Family"] and entity["Family"] == "Animals"
end

local function cloneData(data)
	local clone = {}
	if type(data) ~= "table" then
		return clone
	end

	for key, value in pairs(data) do
		clone[key] = value
	end

	return clone
end

local function getInventoryItemRegistry()
	if InventoryItemRegistry == nil then
		InventoryItemRegistry = require(ReplicatedStorage.Database.InventoryItems.Registry)
	end

	return InventoryItemRegistry
end

local function getItemDropServiceServer()
	if ItemDropServiceServer == nil then
		ItemDropServiceServer = require(ReplicatedStorage.Services.ItemDrop.ItemDropServiceServer)
	end

	return ItemDropServiceServer
end

local function resolveDropGrant(drop)
	local itemKind = drop.ItemKind
	if type(itemKind) ~= "string" or itemKind == "" then
		return nil, nil, nil, nil
	end

	if itemKind == "InventoryItem" then
		local itemId = drop.ItemId
		if type(itemId) ~= "string" or itemId == "" then
			return nil, nil, nil, nil
		end

		local definition = getInventoryItemRegistry().Get(itemId)
		if not definition then
			return nil, nil, nil, nil
		end

		return itemKind, {
			Kind = "Item",
			ItemId = definition.Id,
		}, "InventoryItem:" .. definition.Id, definition.MaxStack
	end

	return itemKind, cloneData(drop.Data), drop.StackKey, drop.MaxStack
end

local function dropBonusMaterials(entity)
	local enemyDrops = (entity :: any).__Drops
	if type(enemyDrops) ~= "table" or #enemyDrops <= 0 then
		return
	end

	local rootPart = entity.RootPart
	local origin = rootPart and rootPart.Position
	if typeof(origin) ~= "Vector3" then
		return
	end

	local rng = Random.new()
	local dropService = getItemDropServiceServer()
	local droppedCount = 0
	local totalDrops = #enemyDrops

	for _, drop in ipairs(enemyDrops) do
		if type(drop) ~= "table" then
			continue
		end

		local quantity = math.max(0, math.floor(drop.Quantity or 1))
		local chance = math.clamp(type(drop.Chance) == "number" and drop.Chance or 1, 0, 1)
		if quantity <= 0 or chance <= 0 or rng:NextNumber() > chance then
			continue
		end

		local itemKind, data, stackKey, maxStack = resolveDropGrant(drop)
		if not itemKind or not stackKey then
			continue
		end

		droppedCount += 1
		local angle = (droppedCount / math.max(1, totalDrops)) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * DROP_SCATTER_RADIUS
		dropService.DropStackGrant(origin + offset, {
			ItemKind = itemKind,
			StackKey = stackKey,
			Quantity = quantity,
			MaxStack = maxStack,
			Data = data,
		})
	end
end

return {
	["Name"] = "Artemis",
	["Type"] = "Sword",
	["Family"] = "Greek",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://123400696561090",

	["BaseDamage"] = 75,
	["__Stats"] = {
		["CritDamage"] = 300,
		["CritRate"] = 0.25,
	},
	["Weight"] = 11,
	["WeaponPassive"] = WeaponPassive.new("weapon:sword:hunt:affinity", {
		["OnApplyMultipliers"] = function(_, attackContext)
			local target = attackContext.To

			if isAnimal(target) then
				local damageModifiers = attackContext.Modifiers.From.Multiplicative
				damageModifiers["PhysicalDamage"] = damageModifiers["PhysicalDamage"] or {}
				damageModifiers["PhysicalDamage"]["hunt_affinity"] =
					Modifier.new("hunt_affinity", "Multiplicative", 2, "weapon:sword:hunt")
			end
		end,
		["OnDefeatEnemy"] = function(_, attackContext)
			local target = attackContext.To

			if isAnimal(target) then
				dropBonusMaterials(target)
				return
			end
		end,
	}, {
		["Name"] = "Hunter's Affinity",
		["Tag"] = "Passive",
		["Desc"] = "Deal twice as much damage against animals. Animals drop twice as much materials.",
		["Values"] = {},
	}),

	["WeaponAbility"] = nil,
	["RightClickAbility"] = nil,

	["Desc"] = "A legendary blade crafted by a legendary hunter. It has an inexplicible power unexplainable to mortals.",
}
