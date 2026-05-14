--!strict

local ItemTypes = require(script.Parent.Parent.Parent.Classes.Item.ItemTypes)

type InventoryItemDefinition = ItemTypes.InventoryItemDefinition

local function loadItemFromFile(folder: Instance): InventoryItemDefinition?
	local dataFile = folder:FindFirstChild("Data", false)
	if dataFile and dataFile:IsA("ModuleScript") then
		local ok, result = pcall(require, dataFile)
		if ok and type(result) == "table" then
			return result
		end
	end
	return nil
end

local function loadItemsFromFolder(folder: Instance): ({ [string]: InventoryItemDefinition }, { [string]: Folder })
	local items: { [string]: InventoryItemDefinition } = {}
	local folders: { [string]: Folder } = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") then
			local itemData = loadItemFromFile(child)
			if itemData then
				items[itemData.Id] = itemData
				folders[itemData.Id] = child
			end
		end
	end
	return items, folders
end

local Items: { [string]: InventoryItemDefinition } = {}
local ItemFolders: { [string]: Folder } = {}

local loadedItems, loadedFolders = loadItemsFromFolder(script.Parent)
for id, item in pairs(loadedItems) do
	Items[id] = item
	ItemFolders[id] = loadedFolders[id]
end

local Registry = {}

function Registry.Get(itemId: string): InventoryItemDefinition?
	return Items[itemId]
end

function Registry.GetAll(): { [string]: InventoryItemDefinition }
	return Items
end

function Registry.GetFolder(itemId: string): Folder?
	return ItemFolders[itemId]
end

function Registry.GetSpawnableItems(): { InventoryItemDefinition }
	local spawnable = {}
	for _, item in pairs(Items) do
		if item.SpawnWith > 0 then
			table.insert(spawnable, item)
		end
	end

	table.sort(spawnable, function(left, right)
		return left.Id < right.Id
	end)

	return spawnable
end

return table.freeze(Registry)
