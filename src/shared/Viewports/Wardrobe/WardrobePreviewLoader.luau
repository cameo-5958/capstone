--!strict

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")
local InventoryItemsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("InventoryItems")

local LoadedPreviewAssetKeys: { [string]: boolean } = {}

local WardrobePreviewLoader = {}

local function preloadInstanceAssets(instance: Instance): boolean
	local loadedCleanly = true
	local ok = pcall(function()
		ContentProvider:PreloadAsync({ instance }, function(_contentId: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				loadedCleanly = false
			end
		end)
	end)

	return ok and loadedCleanly
end

local function resolveWeaponTemplate(weaponId: string): Instance?
	local current: Instance = WeaponsDatabase
	for _, part in ipairs(weaponId:split(".")) do
		local child = current:FindFirstChild(part)
		if not child then
			return nil
		end

		current = child
	end

	local namedModel = current:FindFirstChild("Model")
	if namedModel then
		return namedModel
	end

	for _, child in ipairs(current:GetChildren()) do
		if
			child.Name ~= "Data"
			and (child:IsA("Tool") or child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder"))
		then
			return child
		end
	end

	return nil
end

local function resolveInventoryItemFolder(itemId: string): Folder?
	local folder = InventoryItemsDatabase:FindFirstChild(itemId)
	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

local function buildInventoryItemModel(itemId: string): Model?
	local folder = resolveInventoryItemFolder(itemId)
	if not folder then
		return nil
	end

	local namedModel = folder:FindFirstChild("Model")
	if namedModel and namedModel:IsA("Model") then
		return namedModel:Clone()
	end

	local modelBuilder = folder:FindFirstChild("ModelBuilder")
	if modelBuilder and modelBuilder:IsA("ModuleScript") then
		local ok, exported = pcall(require, modelBuilder)
		if not ok then
			return nil
		end

		local builderFn: (() -> Model)? = nil
		if type(exported) == "function" then
			builderFn = exported
		elseif type(exported) == "table" and type((exported :: any).Build) == "function" then
			builderFn = function()
				return (exported :: any).Build()
			end
		end

		if builderFn then
			local built = builderFn()
			if built and built:IsA("Model") then
				return built
			end
		end
	end

	return nil
end

local function preloadUniqueWeapon(weaponId: string): ()
	local key = "weapon:" .. weaponId
	if LoadedPreviewAssetKeys[key] then
		return
	end

	local template = resolveWeaponTemplate(weaponId)
	if not template then
		return
	end

	preloadInstanceAssets(template)
	LoadedPreviewAssetKeys[key] = true
end

local function preloadUniqueInventoryItem(itemId: string): ()
	local key = "item:" .. itemId
	if LoadedPreviewAssetKeys[key] then
		return
	end

	local folder = resolveInventoryItemFolder(itemId)
	if not folder then
		return
	end

	local namedModel = folder:FindFirstChild("Model")
	if namedModel then
		preloadInstanceAssets(namedModel)
		LoadedPreviewAssetKeys[key] = true
		return
	end

	local builtModel = buildInventoryItemModel(itemId)
	if not builtModel then
		return
	end

	preloadInstanceAssets(builtModel)
	builtModel:Destroy()
	LoadedPreviewAssetKeys[key] = true
end

function WardrobePreviewLoader.PreloadInstanceAssets(instance: Instance): boolean
	return preloadInstanceAssets(instance)
end

function WardrobePreviewLoader.WarmupWardrobeAssets(
	inventory: { Entries: { [string]: { ItemKind: string, Data: { [string]: any } } } },
	weaponLoadout: { Slots: { { WeaponId: string? } } },
	itemLoadout: { Slots: { { ItemId: string? } } }
): ()
	local weaponIds = {}
	local itemIds = {}

	for _, entry in pairs(inventory.Entries or {}) do
		if entry.ItemKind == "Weapon" then
			local weaponId = entry.Data and entry.Data.WeaponId
			if type(weaponId) == "string" and weaponId ~= "" then
				weaponIds[weaponId] = true
			end
		elseif entry.ItemKind == "InventoryItem" then
			local itemId = entry.Data and entry.Data.ItemId
			if type(itemId) == "string" and itemId ~= "" then
				itemIds[itemId] = true
			end
		end
	end

	for _, slot in ipairs(weaponLoadout.Slots or {}) do
		local weaponId = slot and slot.WeaponId
		if type(weaponId) == "string" and weaponId ~= "" then
			weaponIds[weaponId] = true
		end
	end

	for _, slot in ipairs(itemLoadout.Slots or {}) do
		local itemId = slot and slot.ItemId
		if type(itemId) == "string" and itemId ~= "" then
			itemIds[itemId] = true
		end
	end

	for weaponId in pairs(weaponIds) do
		preloadUniqueWeapon(weaponId)
	end

	for itemId in pairs(itemIds) do
		preloadUniqueInventoryItem(itemId)
	end
end

return table.freeze(WardrobePreviewLoader)
