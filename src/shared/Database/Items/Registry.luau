--!strict

local ItemTypes = require(script.Parent.Parent.Parent.Classes.Item.ItemTypes)

type ItemDefinition = ItemTypes.ItemDefinition

-- Load item definitions from individual files
local function loadItemFromFile(folder: Instance): ItemDefinition?
	local dataFile = folder:FindFirstChild("Data", false)
	if dataFile and dataFile:IsA("ModuleScript") then
		local ok, result = pcall(require, dataFile)
		if ok then
			return result
		end
	end
	return nil
end

local function loadItemsFromFolder(folder: Instance): { [string]: ItemDefinition }
	local items: { [string]: ItemDefinition } = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") then
			local itemData = loadItemFromFile(child)
			if itemData then
				items[itemData.Id] = itemData
			end
		end
	end
	return items
end

local Items: { [string]: ItemDefinition } = {}

-- Load banners
local bannersFolder = script.Parent:FindFirstChild("Banners", false)
if bannersFolder then
	local bannerItems = loadItemsFromFolder(bannersFolder)
	for id, item in pairs(bannerItems) do
		Items[id] = item
	end
end

local Registry = {}

function Registry.Get(itemId: string): ItemDefinition?
	return Items[itemId]
end

function Registry.GetAll(): { [string]: ItemDefinition }
	return Items
end

function Registry.GetSpawnableItems(): { ItemDefinition }
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
