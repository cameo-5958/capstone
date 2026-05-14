--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)
local API = script.Parent:WaitForChild("InventoryEndpoint") :: RemoteEvent

export type InventoryEntry = {
	EntryId: string,
	ItemKind: string,
	StorageSection: string,
	StackKey: string,
	Quantity: number,
	MaxStack: number,
	Data: { [string]: any },
}

export type InventorySnapshot = {
	Entries: { [string]: InventoryEntry },
}

local InventoryServiceClient = {}
local COIN_ITEM_KIND = "Currency"
local COIN_STACK_KEY = "Gold"

local InventoryData: InventorySnapshot = {
	Entries = {},
}
local InventoryChanged = Signal.new()
local HasReceivedInitialInventory = false

API.OnClientEvent:Connect(function(action: string, payload: InventorySnapshot?)
	if action == "SyncInventory" then
		InventoryData = payload or { Entries = {} }
		HasReceivedInitialInventory = true
		InventoryChanged:Fire(InventoryData)
	end
end)

task.defer(function()
	API:FireServer("RequestInventory", {})
end)

function InventoryServiceClient.RequestInventory(): ()
	API:FireServer("RequestInventory", {})
end

function InventoryServiceClient.GetInventory(): InventorySnapshot
	return InventoryData
end

function InventoryServiceClient.GetStackQuantity(itemKind: string, stackKey: string, storageSection: string?): number
	local resolvedStorageSection = if type(storageSection) == "string" and storageSection ~= ""
		then storageSection
		else nil
	local normalizedItemKind = if itemKind == "Item" then "Consumable" else itemKind
	local total = 0

	for _, entry in pairs(InventoryData.Entries) do
		if entry.ItemKind == normalizedItemKind and entry.StackKey == stackKey then
			if resolvedStorageSection == nil or entry.StorageSection == resolvedStorageSection then
				total += entry.Quantity
			end
		end
	end

	return total
end

function InventoryServiceClient.GetCoins(): number
	return InventoryServiceClient.GetStackQuantity(COIN_ITEM_KIND, COIN_STACK_KEY)
end

function InventoryServiceClient.GetInventoryChangedSignal()
	return InventoryChanged
end

function InventoryServiceClient.HasReceivedInitialInventory(): boolean
	return HasReceivedInitialInventory
end

return table.freeze(InventoryServiceClient)
