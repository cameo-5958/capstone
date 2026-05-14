--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)
local InventoryServiceClient = require(ReplicatedStorage.Services.Inventory.InventoryServiceClient)
local ItemServiceClient = require(ReplicatedStorage.Services.Item.ItemServiceClient)
local WorldServiceClient = require(ReplicatedStorage.Services.World.WorldServiceClient)

type InventoryEntry = InventoryServiceClient.InventoryEntry
type InventorySnapshot = InventoryServiceClient.InventorySnapshot

export type BroadcastEntry = {
	Id: string,
	Text: string,
	CreatedAt: number,
	ExpiresAt: number,
}

export type BroadcastState = {
	Main: BroadcastEntry?,
	ItemFeed: { BroadcastEntry },
}

local MAIN_BROADCAST_DURATION = 3.6
local ITEM_BROADCAST_DURATION = 4.8
local MAX_ITEM_FEED_ENTRIES = 4

local BroadcastServiceClient = {}

local changedSignal = Signal.new()
local state: BroadcastState = {
	Main = nil,
	ItemFeed = {},
}
local nextBroadcastId = 0
local started = false
local cleanupTaskStarted = false
local hasSeenInventorySync = false
local previousEntriesById: { [string]: InventoryEntry } = {}

local function now(): number
	return os.clock()
end

local function makeId(prefix: string): string
	nextBroadcastId += 1
	return string.format("%s_%d", prefix, nextBroadcastId)
end

local function cloneEntry(entry: InventoryEntry): InventoryEntry
	return {
		EntryId = entry.EntryId,
		ItemKind = entry.ItemKind,
		StorageSection = entry.StorageSection or "General",
		StackKey = entry.StackKey,
		Quantity = entry.Quantity,
		MaxStack = entry.MaxStack,
		Data = table.clone(entry.Data),
	}
end

local function cloneEntriesById(entries: { [string]: InventoryEntry }): { [string]: InventoryEntry }
	local clone = {}
	for entryId, entry in pairs(entries) do
		clone[entryId] = cloneEntry(entry)
	end
	return clone
end

local function emitChanged(): ()
	changedSignal:Fire(BroadcastServiceClient.GetState())
end

local function trimItemFeed(): ()
	while #state.ItemFeed > MAX_ITEM_FEED_ENTRIES do
		table.remove(state.ItemFeed, #state.ItemFeed)
	end
end

local function removeExpiredEntries(): boolean
	local currentTime = now()
	local didChange = false

	if state.Main and currentTime >= state.Main.ExpiresAt then
		state.Main = nil
		didChange = true
	end

	for index = #state.ItemFeed, 1, -1 do
		if currentTime >= state.ItemFeed[index].ExpiresAt then
			table.remove(state.ItemFeed, index)
			didChange = true
		end
	end

	return didChange
end

local function ensureCleanupLoop(): ()
	if cleanupTaskStarted then
		return
	end
	cleanupTaskStarted = true

	task.spawn(function()
		while true do
			task.wait(0.2)
			if removeExpiredEntries() then
				emitChanged()
			end
		end
	end)
end

local function resolveInventoryEntryName(entry: InventoryEntry): string
	local data = entry.Data
	local displayName = data.DisplayName
	if type(displayName) == "string" and displayName ~= "" then
		return displayName
	end

	local itemName = data.Name
	if type(itemName) == "string" and itemName ~= "" then
		return itemName
	end

	local itemId = data.ItemId
	if type(itemId) == "string" and itemId ~= "" then
		return itemId
	end

	local weaponName = data.WeaponId
	if type(weaponName) == "string" and weaponName ~= "" then
		return weaponName
	end

	if entry.StackKey ~= "" then
		return entry.StackKey
	end

	return entry.ItemKind
end

local function addMainBroadcast(text: string, duration: number?): ()
	state.Main = {
		Id = makeId("main"),
		Text = text,
		CreatedAt = now(),
		ExpiresAt = now() + (duration or MAIN_BROADCAST_DURATION),
	}
	emitChanged()
end

local function addItemBroadcast(text: string, duration: number?): ()
	table.insert(state.ItemFeed, 1, {
		Id = makeId("item"),
		Text = text,
		CreatedAt = now(),
		ExpiresAt = now() + (duration or ITEM_BROADCAST_DURATION),
	})
	trimItemFeed()
	emitChanged()
end

local function handleInventoryUpdate(snapshot: InventorySnapshot): ()
	local entries = snapshot.Entries or {}
	if not hasSeenInventorySync then
		previousEntriesById = cloneEntriesById(entries)
		hasSeenInventorySync = true
		return
	end

	local additions = {}
	for entryId, entry in pairs(entries) do
		local previousEntry = previousEntriesById[entryId]
		local previousQuantity = if previousEntry then previousEntry.Quantity else 0
		local gainedQuantity = entry.Quantity - previousQuantity
		if gainedQuantity > 0 then
			table.insert(additions, {
				Name = resolveInventoryEntryName(entry),
				Quantity = gainedQuantity,
				StorageSection = entry.StorageSection or "General",
			})
		end
	end

	table.sort(additions, function(left, right)
		return left.Name < right.Name
	end)

	for _, addition in ipairs(additions) do
		local label = string.format("+%d %s", addition.Quantity, addition.Name)
		addItemBroadcast(label)
	end

	if #additions > 0 then
		local pickedUpCount = 0
		for _, addition in ipairs(additions) do
			if addition.StorageSection == "PickedUp" then
				pickedUpCount += 1
			end
		end

		if pickedUpCount < #additions then
			addMainBroadcast(if #additions == 1 then "Consumable acquired" else "Consumables acquired", 2.4)
		end
	end

	previousEntriesById = cloneEntriesById(entries)
end

function BroadcastServiceClient.init(): ()
	if started then
		return
	end
	started = true

	ensureCleanupLoop()

	InventoryServiceClient.GetInventoryChangedSignal():Connect(handleInventoryUpdate)
	ItemServiceClient.GetUseResultSignal():Connect(function(result: { [string]: any })
		if result.Success ~= true then
			addMainBroadcast("Cannot use item", 2.4)
		end
	end)
	WorldServiceClient.GetTreasureClaimedSignal():Connect(function(payload: { [string]: any })
		local claimedByUserId = payload.ClaimedByUserId
		if claimedByUserId ~= Players.LocalPlayer.UserId then
			return
		end

		local objectText = payload.ObjectText
		if type(objectText) == "string" and objectText ~= "" then
			addMainBroadcast(string.format("%s claimed", objectText), 2.8)
		else
			addMainBroadcast("Treasure claimed", 2.8)
		end
	end)

	local initialInventory = InventoryServiceClient.GetInventory()
	if initialInventory then
		handleInventoryUpdate(initialInventory)
	end
end

function BroadcastServiceClient.PushMainBroadcast(text: string, duration: number?): ()
	addMainBroadcast(text, duration)
end

function BroadcastServiceClient.PushItemBroadcast(text: string, duration: number?): ()
	addItemBroadcast(text, duration)
end

function BroadcastServiceClient.GetState(): BroadcastState
	local itemFeed = table.create(#state.ItemFeed)
	for index, entry in ipairs(state.ItemFeed) do
		itemFeed[index] = {
			Id = entry.Id,
			Text = entry.Text,
			CreatedAt = entry.CreatedAt,
			ExpiresAt = entry.ExpiresAt,
		}
	end

	local mainEntry = state.Main
	return {
		Main = if mainEntry
			then {
				Id = mainEntry.Id,
				Text = mainEntry.Text,
				CreatedAt = mainEntry.CreatedAt,
				ExpiresAt = mainEntry.ExpiresAt,
			}
			else nil,
		ItemFeed = itemFeed,
	}
end

function BroadcastServiceClient.GetChangedSignal()
	return changedSignal
end

return table.freeze(BroadcastServiceClient)
