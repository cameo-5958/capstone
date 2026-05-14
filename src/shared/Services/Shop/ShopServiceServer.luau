--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryItemRegistry = require(ReplicatedStorage.Database.InventoryItems.Registry)
local ConsumableRegistry = require(ReplicatedStorage.Database.Items.Registry)
local ShopConfig = require(ReplicatedStorage.Database.Shops.Default)
local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
local ItemServiceServer = require(ReplicatedStorage.Services.Item.ItemServiceServer)

type InventoryItemDefinition = {
	Id: string,
	Name: string,
	Desc: string,
	Icon: string,
	MaxStack: number,
	SpawnWith: number,
	CanEquip: boolean,
	CanUse: boolean,
	EquipSlotType: string?,
	ModelAssetName: string?,
	InventoryData: { [string]: any }?,
	UseEffects: { [string]: any }?,
}

type CatalogRequirement = {
	ItemKind: string,
	StackKey: string,
	ItemId: string?,
	Name: string,
	Icon: string?,
	Quantity: number,
	StorageSection: string?,
}

type CatalogDisplayEntry = {
	Kind: string,
	Name: string,
	Icon: string?,
	Quantity: number,
}

type CatalogRecipe = {
	Id: string,
	Reward: { CatalogDisplayEntry },
	Coins: number,
	Items: { CatalogRequirement },
	ButtonText: string?,
}

type CatalogPayload = {
	Title: string,
	Recipes: { CatalogRecipe },
}

type ShopRequirement = {
	ItemKind: string?,
	StackKey: string?,
	ItemId: string?,
	Quantity: number?,
	StorageSection: string?,
	Name: string?,
	Icon: string?,
	Data: { [string]: any }?,
	MaxStack: number?,
}

type ShopReward = {
	Kind: string,
	ItemKind: string?,
	StackKey: string?,
	ItemId: string?,
	WeaponPath: string?,
	Quantity: number?,
	Name: string?,
	Icon: string?,
	Data: { [string]: any }?,
	MaxStack: number?,
	StorageSection: string?,
}

type ShopRecipeDefinition = {
	Id: string,
	Reward: ShopReward | { ShopReward },
	Costs: {
		Coins: number?,
		Items: { ShopRequirement }?,
	},
	ButtonText: string?,
}

local endpoint = script.Parent:FindFirstChild("ShopEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "ShopEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent
local ShopServiceServer = {}

local COIN_ITEM_KIND = "Currency"
local COIN_STACK_KEY = "Gold"

local WeaponDataCache: { [string]: { [string]: any }? } = {}
local RecipeById: { [string]: ShopRecipeDefinition } = {}

local function getWeaponData(weaponPath: string): { [string]: any }?
	local cached = WeaponDataCache[weaponPath]
	if cached ~= nil then
		return cached
	end

	local current: Instance = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")
	for _, part in ipairs(weaponPath:split(".")) do
		current = current:FindFirstChild(part) :: Instance
		if not current then
			WeaponDataCache[weaponPath] = false :: any
			return nil
		end
	end

	local dataModule = current:FindFirstChild("Data")
	if not dataModule or not dataModule:IsA("ModuleScript") then
		WeaponDataCache[weaponPath] = false :: any
		return nil
	end

	local ok, result = pcall(require, dataModule)
	if ok and type(result) == "table" then
		WeaponDataCache[weaponPath] = result
		return result
	end

	WeaponDataCache[weaponPath] = false :: any
	return nil
end

local function serializeInventoryItem(definition: InventoryItemDefinition): { [string]: any }
	return {
		Kind = "Item",
		ItemId = definition.Id,
		Name = definition.Name,
		Desc = definition.Desc,
		Icon = definition.Icon,
		MaxStack = definition.MaxStack,
		SpawnWith = definition.SpawnWith,
		StackKey = "InventoryItem:" .. definition.Id,
		CanEquip = definition.CanEquip,
		CanUse = definition.CanUse,
		EquipSlotType = definition.EquipSlotType,
		ModelAssetName = definition.ModelAssetName,
		InventoryData = definition.InventoryData or {},
		UseEffects = definition.UseEffects,
	}
end

local function normalizeQuantity(value: number?): number
	return math.max(0, math.floor(value or 0))
end

local function resolveRequirement(requirement: ShopRequirement): CatalogRequirement?
	local itemKind = requirement.ItemKind
	local quantity = normalizeQuantity(requirement.Quantity)
	if type(itemKind) ~= "string" or itemKind == "" or quantity <= 0 then
		return nil
	end

	if itemKind == "InventoryItem" then
		local itemId = requirement.ItemId
		if type(itemId) ~= "string" or itemId == "" then
			return nil
		end

		local definition = InventoryItemRegistry.Get(itemId)
		if not definition then
			return nil
		end

		return {
			ItemKind = "InventoryItem",
			StackKey = "InventoryItem:" .. definition.Id,
			ItemId = definition.Id,
			Name = definition.Name,
			Icon = definition.Icon,
			Quantity = quantity,
			StorageSection = requirement.StorageSection,
		}
	end

	if itemKind == "Consumable" or itemKind == "Item" then
		local itemId = requirement.ItemId
		if type(itemId) ~= "string" or itemId == "" then
			return nil
		end

		local definition = ConsumableRegistry.Get(itemId)
		if not definition then
			return nil
		end

		return {
			ItemKind = "Consumable",
			StackKey = definition.StackKey or ("Item:" .. definition.Id),
			ItemId = definition.Id,
			Name = definition.Name,
			Icon = definition.Icon,
			Quantity = quantity,
			StorageSection = requirement.StorageSection,
		}
	end

	local stackKey = requirement.StackKey
	if type(stackKey) ~= "string" or stackKey == "" then
		return nil
	end

	return {
		ItemKind = itemKind,
		StackKey = stackKey,
		ItemId = requirement.ItemId,
		Name = if type(requirement.Name) == "string" and requirement.Name ~= "" then requirement.Name else stackKey,
		Icon = requirement.Icon,
		Quantity = quantity,
		StorageSection = requirement.StorageSection,
	}
end

local function resolveRewardDisplay(reward: ShopReward): CatalogDisplayEntry?
	local quantity = math.max(1, normalizeQuantity(reward.Quantity))
	if reward.Kind == "Weapon" then
		local weaponPath = reward.WeaponPath
		if type(weaponPath) ~= "string" or weaponPath == "" then
			return nil
		end

		local data = getWeaponData(weaponPath)
		return {
			Kind = "Weapon",
			Name = if data and type(data.Name) == "string" then data.Name else weaponPath,
			Icon = if data and type(data.Icon) == "string" then data.Icon else nil,
			Quantity = quantity,
		}
	end

	if reward.Kind == "InventoryItem" then
		local itemId = reward.ItemId
		if type(itemId) ~= "string" or itemId == "" then
			return nil
		end

		local definition = InventoryItemRegistry.Get(itemId)
		if not definition then
			return nil
		end

		return {
			Kind = "InventoryItem",
			Name = definition.Name,
			Icon = definition.Icon,
			Quantity = quantity,
		}
	end

	if reward.Kind == "Consumable" or reward.Kind == "Item" then
		local itemId = reward.ItemId
		if type(itemId) ~= "string" or itemId == "" then
			return nil
		end

		local definition = ConsumableRegistry.Get(itemId)
		if not definition then
			return nil
		end

		return {
			Kind = "Consumable",
			Name = definition.Name,
			Icon = definition.Icon,
			Quantity = quantity,
		}
	end

	if reward.Kind == "Coins" or reward.Kind == "Currency" then
		return {
			Kind = "Currency",
			Name = "Coins",
			Icon = nil,
			Quantity = quantity,
		}
	end

	local stackKey = reward.StackKey
	if type(stackKey) ~= "string" or stackKey == "" then
		return nil
	end

	return {
		Kind = reward.Kind,
		Name = if type(reward.Name) == "string" and reward.Name ~= "" then reward.Name else stackKey,
		Icon = reward.Icon,
		Quantity = quantity,
	}
end

local function resolveRewardList(rewardField: ShopReward | { ShopReward }): { CatalogDisplayEntry }
	local resolved = {}
	if type((rewardField :: any).Kind) == "string" then
		local display = resolveRewardDisplay(rewardField :: ShopReward)
		if display then
			table.insert(resolved, display)
		end
	else
		for _, reward in ipairs(rewardField :: { ShopReward }) do
			local display = resolveRewardDisplay(reward)
			if display then
				table.insert(resolved, display)
			end
		end
	end
	return resolved
end

local function buildCatalog(): CatalogPayload
	local recipes = {}
	table.clear(RecipeById)

	for _, recipe in ipairs(ShopConfig.Recipes :: { ShopRecipeDefinition }) do
		local resolvedRequirements = {}
		for _, requirement in ipairs((recipe.Costs.Items or {}) :: { ShopRequirement }) do
			local resolved = resolveRequirement(requirement)
			if resolved then
				table.insert(resolvedRequirements, resolved)
			end
		end

		local rewardList = resolveRewardList(recipe.Reward)
		if #rewardList > 0 then
			RecipeById[recipe.Id] = recipe
			table.insert(recipes, {
				Id = recipe.Id,
				Reward = rewardList,
				Coins = normalizeQuantity(recipe.Costs.Coins),
				Items = resolvedRequirements,
				ButtonText = recipe.ButtonText,
			})
		end
	end

	return {
		Title = if type(ShopConfig.Title) == "string" and ShopConfig.Title ~= "" then ShopConfig.Title else "Shop",
		Recipes = recipes,
	}
end

local Catalog = buildCatalog()

local function hasRequirement(player: Player, requirement: CatalogRequirement): boolean
	return InventoryServiceServer.HasStackQuantity(
		player,
		requirement.ItemKind,
		requirement.StackKey,
		requirement.Quantity,
		requirement.StorageSection
	)
end

local function consumeRequirement(player: Player, requirement: CatalogRequirement): boolean
	return InventoryServiceServer.ConsumeStackQuantity(
		player,
		requirement.ItemKind,
		requirement.StackKey,
		requirement.Quantity,
		requirement.StorageSection
	)
end

local function grantReward(player: Player, reward: ShopReward): boolean
	local quantity = math.max(1, normalizeQuantity(reward.Quantity))

	if reward.Kind == "Weapon" then
		local weaponPath = reward.WeaponPath
		if type(weaponPath) ~= "string" or weaponPath == "" then
			return false
		end

		for _ = 1, quantity do
			InventoryServiceServer.AddWeaponFromPath(player, weaponPath, reward.StorageSection)
		end
		return true
	end

	if reward.Kind == "Coins" or reward.Kind == "Currency" then
		InventoryServiceServer.AddStackableItem(player, COIN_ITEM_KIND, COIN_STACK_KEY, {
			DisplayName = "Coins",
			Kind = "Currency",
		}, quantity, 9999, reward.StorageSection)
		return true
	end

	if reward.Kind == "InventoryItem" then
		local itemId = reward.ItemId
		if type(itemId) ~= "string" or itemId == "" then
			return false
		end

		local definition = InventoryItemRegistry.Get(itemId)
		if not definition then
			return false
		end

		InventoryServiceServer.AddStackableItem(
			player,
			"InventoryItem",
			"InventoryItem:" .. definition.Id,
			serializeInventoryItem(definition),
			quantity,
			definition.MaxStack,
			reward.StorageSection
		)
		return true
	end

	if reward.Kind == "Consumable" or reward.Kind == "Item" then
		local itemId = reward.ItemId
		if type(itemId) ~= "string" or itemId == "" then
			return false
		end

		ItemServiceServer.AddConsumableToInventory(player, itemId, quantity)
		return true
	end

	local itemKind = reward.ItemKind or reward.Kind
	local stackKey = reward.StackKey
	if type(itemKind) ~= "string" or itemKind == "" or type(stackKey) ~= "string" or stackKey == "" then
		return false
	end

	InventoryServiceServer.AddStackableItem(
		player,
		itemKind,
		stackKey,
		reward.Data or {
			DisplayName = reward.Name or stackKey,
		},
		quantity,
		reward.MaxStack,
		reward.StorageSection
	)
	return true
end

local function grantRewardSet(player: Player, rewardField: ShopReward | { ShopReward }): boolean
	if type((rewardField :: any).Kind) == "string" then
		return grantReward(player, rewardField :: ShopReward)
	end

	local grantedAny = false
	for _, reward in ipairs(rewardField :: { ShopReward }) do
		grantedAny = grantReward(player, reward) or grantedAny
	end
	return grantedAny
end

local function purchase(player: Player, recipeId: string): (boolean, string)
	local recipe = RecipeById[recipeId]
	if not recipe then
		return false, "UnknownRecipe"
	end

	local coinCost = normalizeQuantity(recipe.Costs.Coins)
	if coinCost > 0 and not InventoryServiceServer.HasCoins(player, coinCost) then
		return false, "NotEnoughCoins"
	end

	local resolvedRequirements = {}
	for _, requirement in ipairs((recipe.Costs.Items or {}) :: { ShopRequirement }) do
		local resolved = resolveRequirement(requirement)
		if resolved then
			table.insert(resolvedRequirements, resolved)
			if not hasRequirement(player, resolved) then
				return false, "MissingItems"
			end
		end
	end

	if coinCost > 0 and not InventoryServiceServer.ConsumeCoins(player, coinCost) then
		return false, "NotEnoughCoins"
	end

	for _, requirement in ipairs(resolvedRequirements) do
		if not consumeRequirement(player, requirement) then
			return false, "MissingItems"
		end
	end

	if not grantRewardSet(player, recipe.Reward) then
		return false, "GrantFailed"
	end

	return true, "Purchased"
end

function ShopServiceServer.init(): ()
	Catalog = buildCatalog()
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "RequestCatalog" then
		API:FireClient(player, "Catalog", Catalog)
	elseif action == "Purchase" then
		local recipeId = payload and payload.RecipeId
		if type(recipeId) ~= "string" or recipeId == "" then
			API:FireClient(player, "PurchaseResult", {
				RecipeId = "",
				Success = false,
				Reason = "InvalidRecipe",
			})
			return
		end

		local success, reason = purchase(player, recipeId)
		API:FireClient(player, "PurchaseResult", {
			RecipeId = recipeId,
			Success = success,
			Reason = reason,
		})
	end
end)

return table.freeze(ShopServiceServer)
