--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)

type ItemLoadoutSlot = {
	Slot: number,
	EntryId: string?,
	ItemId: string?,
	Name: string?,
}

type ItemLoadoutSnapshot = {
	Slots: { ItemLoadoutSlot },
}

local API = script.Parent:WaitForChild("ItemToolEndpoint") :: RemoteEvent

local ITEM_SLOT_COUNT = 2

local function createDefaultLoadout(): ItemLoadoutSnapshot
	local slots = {}
	for slot = 1, ITEM_SLOT_COUNT do
		slots[slot] = {
			Slot = slot,
		}
	end

	return {
		Slots = slots,
	}
end

local ItemToolServiceClient = {}

local LoadoutData: ItemLoadoutSnapshot = createDefaultLoadout()
local LoadoutChanged = Signal.new()

API.OnClientEvent:Connect(function(action: string, payload: ItemLoadoutSnapshot?)
	if action == "SyncLoadout" then
		LoadoutData = payload or createDefaultLoadout()
		LoadoutChanged:Fire(LoadoutData)
	end
end)

task.defer(function()
	API:FireServer("RequestLoadout", {})
end)

function ItemToolServiceClient.GetLoadoutData(): ItemLoadoutSnapshot
	return LoadoutData
end

function ItemToolServiceClient.GetLoadoutChangedSignal()
	return LoadoutChanged
end

function ItemToolServiceClient.RequestLoadout(): ()
	API:FireServer("RequestLoadout", {})
end

function ItemToolServiceClient.EquipInventoryEntry(entryId: string): ()
	API:FireServer("EquipInventoryEntry", {
		EntryId = entryId,
	})
end

function ItemToolServiceClient.EquipInventoryEntryToSlot(entryId: string, slot: number): ()
	API:FireServer("EquipInventoryEntry", {
		EntryId = entryId,
		Slot = slot,
	})
end

function ItemToolServiceClient.UnequipSlot(slot: number): ()
	API:FireServer("UnequipSlot", {
		Slot = slot,
	})
end

return table.freeze(ItemToolServiceClient)
