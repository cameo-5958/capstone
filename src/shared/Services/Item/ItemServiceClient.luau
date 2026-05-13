--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)

local API = script.Parent:WaitForChild("ItemEndpoint") :: RemoteEvent

local ItemServiceClient = {}

local CatalogData: { [string]: any } = {}
local LastUseResult: { [string]: any }? = nil
local CatalogChanged = Signal.new()
local ItemUseResult = Signal.new()

API.OnClientEvent:Connect(function(action: string, payload: any)
	if action == "Catalog" then
		CatalogData = payload or {}
		CatalogChanged:Fire(CatalogData)
	elseif action == "UseResult" then
		LastUseResult = payload
		ItemUseResult:Fire(payload)
	end
end)

task.defer(function()
	API:FireServer("RequestCatalog", {})
end)

function ItemServiceClient.RequestCatalog(): ()
	API:FireServer("RequestCatalog", {})
end

function ItemServiceClient.GetCatalog(): { [string]: any }
	return CatalogData
end

function ItemServiceClient.GetCatalogChangedSignal()
	return CatalogChanged
end

function ItemServiceClient.UseInventoryEntry(entryId: string): ()
	API:FireServer("UseInventoryEntry", {
		EntryId = entryId,
	})
end

function ItemServiceClient.GetLastUseResult(): { [string]: any }?
	return LastUseResult
end

function ItemServiceClient.GetUseResultSignal()
	return ItemUseResult
end

return table.freeze(ItemServiceClient)
