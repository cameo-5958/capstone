--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)

type ItemLoadoutSlot = {
	Slot: number,
	EntryId: string?,
	ItemId: string?,
	Name: string?,
	Icon: string?,
	Quantity: number?,
	MaxStack: number?,
}

type ItemLoadoutSnapshot = {
	Slots: { ItemLoadoutSlot },
}

local API = script.Parent:WaitForChild("ItemLoadoutEndpoint") :: RemoteEvent

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

local ItemLoadoutServiceClient = {}

local LoadoutData: ItemLoadoutSnapshot = createDefaultLoadout()
local LoadoutChanged = Signal.new()
local HasReceivedInitialLoadout = false

API.OnClientEvent:Connect(function(action: string, payload: ItemLoadoutSnapshot?)
	if action == "SyncLoadout" then
		LoadoutData = payload or createDefaultLoadout()
		HasReceivedInitialLoadout = true
		LoadoutChanged:Fire(LoadoutData)
	end
end)

task.defer(function()
	API:FireServer("RequestLoadout", {})
end)

function ItemLoadoutServiceClient.GetLoadoutData(): ItemLoadoutSnapshot
	return LoadoutData
end

function ItemLoadoutServiceClient.GetLoadoutChangedSignal()
	return LoadoutChanged
end

function ItemLoadoutServiceClient.RequestLoadout(): ()
	API:FireServer("RequestLoadout", {})
end

function ItemLoadoutServiceClient.EquipInventoryEntry(entryId: string): ()
	API:FireServer("EquipInventoryEntry", {
		EntryId = entryId,
	})
end

function ItemLoadoutServiceClient.EquipInventoryEntryToSlot(entryId: string, slot: number): ()
	API:FireServer("EquipInventoryEntry", {
		EntryId = entryId,
		Slot = slot,
	})
end

function ItemLoadoutServiceClient.UnequipSlot(slot: number): ()
	API:FireServer("UnequipSlot", {
		Slot = slot,
	})
end

function ItemLoadoutServiceClient.UseSlot(slot: number): ()
	API:FireServer("UseSlot", {
		Slot = slot,
	})
end

function ItemLoadoutServiceClient.HasReceivedInitialLoadout(): boolean
	return HasReceivedInitialLoadout
end

return table.freeze(ItemLoadoutServiceClient)
