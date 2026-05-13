--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
local ItemServiceServer = require(ReplicatedStorage.Services.Item.ItemServiceServer)

type InventoryEntry = InventoryServiceServer.InventoryEntry

type ItemLoadout = { [number]: string? }

type ItemLoadoutSlot = {
	Slot: number,
	EntryId: string?,
	ItemId: string?,
	Name: string?,
}

type ItemLoadoutSnapshot = {
	Slots: { ItemLoadoutSlot },
}

local endpoint = script.Parent:FindFirstChild("ItemToolEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "ItemToolEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent
local ItemToolServiceServer = {}

local ITEM_SLOT_COUNT = 2
local MANAGED_ATTRIBUTE = "ManagedByItemToolService"
local SLOT_ATTRIBUTE = "ItemToolSlot"
local ENTRY_ATTRIBUTE = "ItemEntryId"

local PlayerLoadouts: { [Player]: ItemLoadout } = {}
local PlayerConnections: { [Player]: { RBXScriptConnection } } = {}
local PlayerToolConnections: { [Player]: { [Tool]: RBXScriptConnection } } = {}

local function getLoadout(player: Player): ItemLoadout
	local loadout = PlayerLoadouts[player]
	if loadout then
		return loadout
	end

	loadout = {}
	PlayerLoadouts[player] = loadout
	return loadout
end

local function getBackpack(player: Player): Backpack?
	return player:FindFirstChildOfClass("Backpack")
end

local function getInventoryItemEntry(player: Player, entryId: string): InventoryEntry?
	local entry = InventoryServiceServer.GetEntry(player, entryId)
	if not entry or entry.ItemKind ~= "Item" then
		return nil
	end

	return entry
end

local function getToolNameFromEntry(entry: InventoryEntry): string
	local data = entry.Data
	if type(data) == "table" then
		local name = data.Name
		if type(name) == "string" and name ~= "" then
			return name
		end

		local itemId = data.ItemId
		if type(itemId) == "string" and itemId ~= "" then
			return itemId
		end
	end

	return "Item"
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

local function disconnectToolConnection(player: Player, tool: Tool)
	local connectionsByTool = PlayerToolConnections[player]
	if not connectionsByTool then
		return
	end

	local connection = connectionsByTool[tool]
	if connection then
		connection:Disconnect()
		connectionsByTool[tool] = nil
	end

	if next(connectionsByTool) == nil then
		PlayerToolConnections[player] = nil
	end
end

local function clearManagedToolsInContainer(player: Player, container: Instance?)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute(MANAGED_ATTRIBUTE) == true then
			disconnectToolConnection(player, child)
			child:Destroy()
		end
	end
end

local function clearManagedTools(player: Player)
	clearManagedToolsInContainer(player, getBackpack(player))
	clearManagedToolsInContainer(player, player.Character)
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

				local data = entry.Data
				if type(data) == "table" then
					if type(data.ItemId) == "string" and data.ItemId ~= "" then
						serializedSlot.ItemId = data.ItemId
					end

					if type(data.Name) == "string" and data.Name ~= "" then
						serializedSlot.Name = data.Name
					end
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
	API:FireClient(player, "SyncLoadout", serializeLoadout(player))
end

local function equipEntryToolForSlot(player: Player, slot: number, entryId: string)
	local entry = getInventoryItemEntry(player, entryId)
	if not entry then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = getToolNameFromEntry(entry)
	tool.ToolTip = tool.Name
	tool.TextureId = ""
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute(MANAGED_ATTRIBUTE, true)
	tool:SetAttribute(SLOT_ATTRIBUTE, slot)
	tool:SetAttribute(ENTRY_ATTRIBUTE, entryId)

	local activatedConnection = tool.Activated:Connect(function()
		local activeLoadout = getLoadout(player)
		if activeLoadout[slot] ~= entryId then
			return
		end

		local used = ItemServiceServer.UseInventoryEntry(player, entryId)
		if not used then
			return
		end

		reconcileLoadoutAgainstInventory(player)
		clearManagedTools(player)

		local nextLoadout = getLoadout(player)
		for nextSlot = 1, ITEM_SLOT_COUNT do
			local nextEntryId = nextLoadout[nextSlot]
			if type(nextEntryId) == "string" and nextEntryId ~= "" then
				equipEntryToolForSlot(player, nextSlot, nextEntryId)
			end
		end

		syncLoadout(player)
	end)

	local connectionsByTool = PlayerToolConnections[player]
	if not connectionsByTool then
		connectionsByTool = {}
		PlayerToolConnections[player] = connectionsByTool
	end
	connectionsByTool[tool] = activatedConnection

	tool.Destroying:Connect(function()
		disconnectToolConnection(player, tool)
	end)

	local backpack = getBackpack(player)
	if backpack then
		tool.Parent = backpack
	elseif player.Character then
		tool.Parent = player.Character
	else
		tool:Destroy()
	end
end

local function rebuildTools(player: Player)
	clearManagedTools(player)

	local loadout = getLoadout(player)
	for slot = 1, ITEM_SLOT_COUNT do
		local entryId = loadout[slot]
		if type(entryId) == "string" and entryId ~= "" then
			equipEntryToolForSlot(player, slot, entryId)
		end
	end
end

local function refreshPlayerToolsAndLoadout(player: Player)
	reconcileLoadoutAgainstInventory(player)
	rebuildTools(player)
	syncLoadout(player)
end

local function disconnectPlayerConnections(player: Player)
	local connections = PlayerConnections[player]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	PlayerConnections[player] = nil
end

function ItemToolServiceServer.EquipInventoryEntry(player: Player, entryId: string, targetSlot: number?): boolean
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

	refreshPlayerToolsAndLoadout(player)
	return true
end

function ItemToolServiceServer.ClearSlot(player: Player, slot: number?): boolean
	if type(slot) ~= "number" then
		return false
	end

	local flooredSlot = math.floor(slot)
	if flooredSlot < 1 or flooredSlot > ITEM_SLOT_COUNT then
		return false
	end

	local loadout = getLoadout(player)
	loadout[flooredSlot] = nil

	refreshPlayerToolsAndLoadout(player)
	return true
end

function ItemToolServiceServer.SyncLoadout(player: Player)
	reconcileLoadoutAgainstInventory(player)
	syncLoadout(player)
end

function ItemToolServiceServer.init()
	for _, player in ipairs(Players:GetPlayers()) do
		getLoadout(player)
		disconnectPlayerConnections(player)
		PlayerConnections[player] = {
			player.CharacterAdded:Connect(function()
				task.defer(function()
					if player.Parent == nil then
						return
					end

					refreshPlayerToolsAndLoadout(player)
				end)
			end),
		}
		task.defer(function()
			if player.Parent then
				refreshPlayerToolsAndLoadout(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		getLoadout(player)
		disconnectPlayerConnections(player)
		PlayerConnections[player] = {
			player.CharacterAdded:Connect(function()
				task.defer(function()
					if player.Parent == nil then
						return
					end

					refreshPlayerToolsAndLoadout(player)
				end)
			end),
		}

		task.defer(function()
			if player.Parent then
				refreshPlayerToolsAndLoadout(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		disconnectPlayerConnections(player)
		clearManagedTools(player)

		local connectionsByTool = PlayerToolConnections[player]
		if connectionsByTool then
			for _, connection in pairs(connectionsByTool) do
				connection:Disconnect()
			end
			PlayerToolConnections[player] = nil
		end

		PlayerLoadouts[player] = nil
	end)
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "EquipInventoryEntry" then
		ItemToolServiceServer.EquipInventoryEntry(player, payload and payload.EntryId or "", payload and payload.Slot or nil)
	elseif action == "UnequipSlot" then
		ItemToolServiceServer.ClearSlot(player, payload and payload.Slot or nil)
	elseif action == "RequestLoadout" then
		ItemToolServiceServer.SyncLoadout(player)
	end
end)

return table.freeze(ItemToolServiceServer)
