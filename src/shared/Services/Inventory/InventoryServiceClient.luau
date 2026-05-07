--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)
local API = script.Parent:WaitForChild("InventoryEndpoint") :: RemoteEvent

type InventoryEntry = {
	EntryId: string,
	ItemKind: string,
	StackKey: string,
	Quantity: number,
	MaxStack: number,
	Data: { [string]: any },
}

type InventorySnapshot = {
	Entries: { [string]: InventoryEntry },
}

local InventoryServiceClient = {}

local InventoryData: InventorySnapshot = {
	Entries = {},
}
local InventoryChanged = Signal.new()

API.OnClientEvent:Connect(function(action: string, payload: InventorySnapshot?)
	if action == "SyncInventory" then
		InventoryData = payload or { Entries = {} }
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

function InventoryServiceClient.GetInventoryChangedSignal()
	return InventoryChanged
end

return table.freeze(InventoryServiceClient)
