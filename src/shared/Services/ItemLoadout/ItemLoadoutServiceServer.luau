--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
local ItemServiceServer = require(ReplicatedStorage.Services.Item.ItemServiceServer)
local WorldServiceServer = require(ReplicatedStorage.Services.World.WorldServiceServer)

type InventoryEntry = InventoryServiceServer.InventoryEntry

type ItemLoadout = { [number]: string? }

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

local endpoint = script.Parent:FindFirstChild("ItemLoadoutEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "ItemLoadoutEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent
local ItemLoadoutServiceServer = {}

local ITEM_SLOT_COUNT = 2
local PlayerLoadouts: { [Player]: ItemLoadout } = {}

local function isLoadoutItemKind(itemKind: string): boolean
	return itemKind == "Consumable" or itemKind == "Item" or itemKind == "InventoryItem"
end

local function getLoadout(player: Player): ItemLoadout
	local loadout = PlayerLoadouts[player]
	if loadout then
		return loadout
	end

	loadout = {}
	PlayerLoadouts[player] = loadout
	return loadout
end

local function getInventoryItemEntry(player: Player, entryId: string): InventoryEntry?
	local entry = InventoryServiceServer.GetEntry(player, entryId)
	if not entry or not isLoadoutItemKind(entry.ItemKind) then
		return nil
	end

	return entry
end

local function getFirstEmptySlot(loadout: ItemLoadout): number
	for slot = 1, ITEM_SLOT_COUNT do
		if loadout[slot] == nil then
			return slot
		end
	end

	return ITEM_SLOT_COUNT
end

local function findEntrySlot(loadout: ItemLoadout, entryId: string): number?
	for slot = 1, ITEM_SLOT_COUNT do
		if loadout[slot] == entryId then
			return slot
		end
	end

	return nil
end

local function getEntryName(entry: InventoryEntry): string?
	local data = entry.Data
	if type(data) ~= "table" then
		return nil
	end

	local name = data.Name
	if type(name) == "string" and name ~= "" then
		return name
	end

	local itemId = data.ItemId
	if type(itemId) == "string" and itemId ~= "" then
		return itemId
	end

	return nil
end

local function getEntryIcon(entry: InventoryEntry): string?
	local data = entry.Data
	if type(data) ~= "table" then
		return nil
	end

	local icon = data.Icon or data.IconImage or data.Image
	if type(icon) == "string" and icon ~= "" then
		return icon
	end

	return nil
end

local function reconcileLoadoutAgainstInventory(player: Player): boolean
	local loadout = getLoadout(player)
	local changed = false
	local seenEntries: { [string]: boolean } = {}

	for slot = 1, ITEM_SLOT_COUNT do
		local entryId = loadout[slot]
		if entryId ~= nil then
			if type(entryId) ~= "string" or entryId == "" then
				loadout[slot] = nil
				changed = true
			else
				local entry = getInventoryItemEntry(player, entryId)
				if not entry or seenEntries[entryId] then
					loadout[slot] = nil
					changed = true
				else
					seenEntries[entryId] = true
				end
			end
		end
	end

	return changed
end

local function serializeLoadout(player: Player): ItemLoadoutSnapshot
	local slots = {}
	local loadout = getLoadout(player)

	for slot = 1, ITEM_SLOT_COUNT do
		local serializedSlot: ItemLoadoutSlot = {
			Slot = slot,
		}

		local entryId = loadout[slot]
		if type(entryId) == "string" then
			local entry = getInventoryItemEntry(player, entryId)
			if entry then
				serializedSlot.EntryId = entry.EntryId
				serializedSlot.Quantity = entry.Quantity
				serializedSlot.MaxStack = entry.MaxStack

				local data = entry.Data
				if type(data) == "table" then
					if type(data.ItemId) == "string" and data.ItemId ~= "" then
						serializedSlot.ItemId = data.ItemId
					end

					serializedSlot.Name = getEntryName(entry)
					serializedSlot.Icon = getEntryIcon(entry)
				end
			end
		end

		slots[slot] = serializedSlot
	end

	return {
		Slots = slots,
	}
end

local function syncLoadout(player: Player)
	reconcileLoadoutAgainstInventory(player)
	API:FireClient(player, "SyncLoadout", serializeLoadout(player))
end

function ItemLoadoutServiceServer.EquipInventoryEntry(player: Player, entryId: string, targetSlot: number?): boolean
	if type(entryId) ~= "string" or entryId == "" then
		return false
	end

	if not getInventoryItemEntry(player, entryId) then
		return false
	end

	local resolvedSlot: number?
	if targetSlot ~= nil then
		if type(targetSlot) ~= "number" then
			return false
		end

		local flooredSlot = math.floor(targetSlot)
		if flooredSlot < 1 or flooredSlot > ITEM_SLOT_COUNT then
			return false
		end
		resolvedSlot = flooredSlot
	end

	local loadout = getLoadout(player)
	local existingSlot = findEntrySlot(loadout, entryId)
	if resolvedSlot == nil then
		resolvedSlot = existingSlot or getFirstEmptySlot(loadout)
	end

	if existingSlot and existingSlot ~= resolvedSlot then
		loadout[existingSlot] = nil
	end

	loadout[resolvedSlot] = entryId
	syncLoadout(player)
	return true
end

function ItemLoadoutServiceServer.ClearSlot(player: Player, slot: number?): boolean
	if type(slot) ~= "number" then
		return false
	end

	local flooredSlot = math.floor(slot)
	if flooredSlot < 1 or flooredSlot > ITEM_SLOT_COUNT then
		return false
	end

	local loadout = getLoadout(player)
	loadout[flooredSlot] = nil
	syncLoadout(player)
	return true
end

function ItemLoadoutServiceServer.UseSlot(player: Player, slot: number?): boolean
	if type(slot) ~= "number" then
		return false
	end

	local flooredSlot = math.floor(slot)
	if flooredSlot < 1 or flooredSlot > ITEM_SLOT_COUNT then
		return false
	end

	local loadout = getLoadout(player)
	local entryId = loadout[flooredSlot]
	if type(entryId) ~= "string" or entryId == "" then
		return false
	end

	local used = ItemServiceServer.UseInventoryEntry(player, entryId)
	syncLoadout(player)
	return used
end

function ItemLoadoutServiceServer.SyncLoadout(player: Player)
	syncLoadout(player)
end

function ItemLoadoutServiceServer.init()
	for _, player in ipairs(Players:GetPlayers()) do
		syncLoadout(player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			if player.Parent then
				syncLoadout(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerLoadouts[player] = nil
	end)
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "EquipInventoryEntry" then
		if WorldServiceServer.IsPlayerWardrobeLocked(player) then
			return
		end
		ItemLoadoutServiceServer.EquipInventoryEntry(player, payload and payload.EntryId or "", payload and payload.Slot or nil)
	elseif action == "UnequipSlot" then
		if WorldServiceServer.IsPlayerWardrobeLocked(player) then
			return
		end
		ItemLoadoutServiceServer.ClearSlot(player, payload and payload.Slot or nil)
	elseif action == "UseSlot" then
		if not WorldServiceServer.IsMatchStarted() then
			return
		end
		ItemLoadoutServiceServer.UseSlot(player, payload and payload.Slot or nil)
	elseif action == "RequestLoadout" then
		ItemLoadoutServiceServer.SyncLoadout(player)
	end
end)

return table.freeze(ItemLoadoutServiceServer)
