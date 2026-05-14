--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)
local API = script.Parent:WaitForChild("ShopEndpoint") :: RemoteEvent

export type ShopDisplayEntry = {
	Kind: string,
	Name: string,
	Icon: string?,
	Quantity: number,
}

export type ShopItemRequirement = {
	ItemKind: string,
	StackKey: string,
	ItemId: string?,
	Name: string,
	Icon: string?,
	Quantity: number,
	StorageSection: string?,
}

export type ShopRecipe = {
	Id: string,
	Reward: { ShopDisplayEntry },
	Coins: number,
	Items: { ShopItemRequirement },
	ButtonText: string?,
}

export type ShopCatalog = {
	Title: string,
	Recipes: { ShopRecipe },
}

export type PurchaseResult = {
	RecipeId: string,
	Success: boolean,
	Reason: string,
}

local ShopServiceClient = {}

local catalogChanged = Signal.new()
local purchaseResultSignal = Signal.new()
local catalog: ShopCatalog = {
	Title = "Shop",
	Recipes = {},
}
local hasReceivedCatalog = false

API.OnClientEvent:Connect(function(action: string, payload: any)
	if action == "Catalog" and type(payload) == "table" then
		catalog = payload :: ShopCatalog
		hasReceivedCatalog = true
		catalogChanged:Fire(catalog)
	elseif action == "PurchaseResult" and type(payload) == "table" then
		purchaseResultSignal:Fire(payload :: PurchaseResult)
	end
end)

task.defer(function()
	API:FireServer("RequestCatalog", {})
end)

function ShopServiceClient.RequestCatalog(): ()
	API:FireServer("RequestCatalog", {})
end

function ShopServiceClient.Purchase(recipeId: string): ()
	API:FireServer("Purchase", {
		RecipeId = recipeId,
	})
end

function ShopServiceClient.GetCatalog(): ShopCatalog
	return catalog
end

function ShopServiceClient.HasReceivedCatalog(): boolean
	return hasReceivedCatalog
end

function ShopServiceClient.GetCatalogChangedSignal()
	return catalogChanged
end

function ShopServiceClient.GetPurchaseResultSignal()
	return purchaseResultSignal
end

return table.freeze(ShopServiceClient)
