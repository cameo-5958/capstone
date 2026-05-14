--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentServiceServer = require(ReplicatedStorage.Services.Equipment.EquipmentServiceServer)
local WeaponTypes = require(ReplicatedStorage.Classes.Weapon.WeaponTypes)

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")

local function resolveWeaponFolder(weaponPath: string): Instance?
	local current: Instance = WeaponsDatabase
	for _, part in ipairs(weaponPath:split(".")) do
		current = current:FindFirstChild(part)
		if not current then
			return nil
		end
	end
	return current
end

local function getWeaponDatabaseData(weaponPath: string): { [string]: any }?
	local folder = resolveWeaponFolder(weaponPath)
	if not folder then
		return nil
	end

	local data = folder:FindFirstChild("Data")
	if data and data:IsA("ModuleScript") then
		local ok, result = pcall(require, data)
		if ok and type(result) == "table" then
			return result
		end
	end

	return nil
end

type Weapon = WeaponTypes.Weapon

export type SerializedWeaponData = {
	Kind: "Weapon",
	InstanceId: string,
	WeaponId: string,
	Name: string,
	Rarity: string,
	Class: string,
	Type: string,
	AttackContext: { [string]: any },
	BaseDamage: number,
	GrantedStats: { [string]: number },
	Weight: number,
	HasPassive: boolean,
	HasAbility: boolean,
	PassiveDetails: { [number]: { [string]: any } },
}

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

local endpoint = script.Parent:FindFirstChild("InventoryEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "InventoryEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent
local InventoryServiceServer = {}

local DEFAULT_MAX_STACK = 1000
local WEAPON_MAX_STACK = 1
local DEFAULT_STORAGE_SECTION = "General"
local COIN_ITEM_KIND = "Currency"
local COIN_STACK_KEY = "Gold"

--[[
	Inventory save model:

	- This service owns inventory state only. Hotbar/equipped weapon state is not
	  stored here and should stay in the equipment/weapon services until a later
	  integration step.
	- Inventories are intentionally unordered. PlayerInventories[player].Entries is
	  a dictionary keyed by EntryId, not an array/slot list.
	- Every entry is save-ready data:
	      Entries[entryId] = {
	          EntryId = "...",
	          ItemKind = "Weapon" | future item kind,
	          StackKey = "...",
	          Quantity = number,
	          MaxStack = number,
	          Data = serialized item payload,
	      }
	- Weapons are nonstackable, so Quantity and MaxStack are always 1. Their Data
	  payload stores only serialized weapon fields, never Tool instances,
	  callbacks, owners, hotbar slots, or passive functions.
	- PassiveDetails is display/save metadata only. Runtime passive behavior is
	  rebuilt from the weapon database when a serialized weapon is equipped.
	- Future stackable items should reuse StackKey to merge matching stacks up to
	  MaxStack. MaxStack is capped at DEFAULT_MAX_STACK, currently 1000.
	- This is in-memory for now. If/when DataStore is added, persist the
	  InventorySnapshot shape returned by InventoryServiceServer.GetSnapshot().
]]
local PlayerInventories: { [Player]: InventorySnapshot } = {}

local function cloneSerializable(value: any): any
	local valueType = type(value)
	if valueType == "table" then
		local clone = {}
		for key, child in pairs(value) do
			local keyType = type(key)
			if keyType == "string" or keyType == "number" then
				local clonedChild = cloneSerializable(child)
				if clonedChild ~= nil then
					clone[key] = clonedChild
				end
			end
		end
		return clone
	elseif valueType == "string" or valueType == "number" or valueType == "boolean" then
		return value
	end

	local robloxType = typeof(value)
	if robloxType == "Vector3" or robloxType == "Vector2" or robloxType == "Color3" or robloxType == "CFrame" then
		return value
	end

	return nil
end

local function cloneInventoryEntry(entry: InventoryEntry): InventoryEntry
	return {
		EntryId = entry.EntryId,
		ItemKind = entry.ItemKind,
		StorageSection = entry.StorageSection or DEFAULT_STORAGE_SECTION,
		StackKey = entry.StackKey,
		Quantity = entry.Quantity,
		MaxStack = entry.MaxStack,
		Data = cloneSerializable(entry.Data) or {},
	}
end

local function clampMaxStack(maxStack: number?): number
	local resolvedMaxStack = maxStack or DEFAULT_MAX_STACK
	return math.clamp(math.floor(resolvedMaxStack), 1, DEFAULT_MAX_STACK)
end

local function getInventory(player: Player): InventorySnapshot
	local inventory = PlayerInventories[player]
	if inventory then
		return inventory
	end

	inventory = {
		Entries = {},
	}
	PlayerInventories[player] = inventory
	return inventory
end

local function createEntry(
	itemKind: string,
	storageSection: string,
	stackKey: string,
	quantity: number,
	maxStack: number,
	data: { [string]: any }
): InventoryEntry
	return {
		EntryId = HttpService:GenerateGUID(false),
		ItemKind = itemKind,
		StorageSection = storageSection,
		StackKey = stackKey,
		Quantity = quantity,
		MaxStack = maxStack,
		Data = cloneSerializable(data) or {},
	}
end

local function getMatchingEntries(
	player: Player,
	itemKind: string,
	stackKey: string,
	storageSection: string?
): { InventoryEntry }
	local inventory = getInventory(player)
	local matches = {}
	local resolvedStorageSection = if type(storageSection) == "string" and storageSection ~= ""
		then storageSection
		else nil
	local normalizedItemKind = if itemKind == "Item" then "Consumable" else itemKind

	for _, entry in pairs(inventory.Entries) do
		if entry.ItemKind == normalizedItemKind and entry.StackKey == stackKey then
			if resolvedStorageSection == nil or entry.StorageSection == resolvedStorageSection then
				table.insert(matches, entry)
			end
		end
	end

	table.sort(matches, function(left, right)
		return left.Quantity < right.Quantity
	end)

	return matches
end

local function serializeWeapon(weapon: Weapon): SerializedWeaponData
	local icon: string? = nil
	local databaseData = getWeaponDatabaseData(weapon.WeaponId)
	if type(databaseData) == "table" then
		local databaseIcon = databaseData.Icon or databaseData.IconImage or databaseData.Image
		if type(databaseIcon) == "string" and databaseIcon ~= "" then
			icon = databaseIcon
		end
	end

	return {
		Kind = "Weapon",
		InstanceId = weapon.UUID,
		WeaponId = weapon.WeaponId,
		Name = weapon.Name,
		Rarity = weapon.Rarity,
		Class = weapon.Class,
		Type = weapon.Type,
		AttackContext = weapon:GetAttackContext(),
		BaseDamage = weapon.BaseDamage,
		GrantedStats = table.clone(weapon.GrantedStats),
		Weight = weapon.Weight,
		HasPassive = weapon.WeaponPassive ~= nil or #weapon.PassiveDetails > 0,
		HasAbility = weapon.WeaponAbility ~= nil,
		PassiveDetails = cloneSerializable(weapon.PassiveDetails) or {},
		Icon = icon,
	}
end

local function getSnapshot(player: Player): InventorySnapshot
	local inventory = getInventory(player)
	local entries = {}
	for entryId, entry in pairs(inventory.Entries) do
		entries[entryId] = cloneInventoryEntry(entry)
	end

	return {
		Entries = entries,
	}
end

local function syncInventory(player: Player): ()
	API:FireClient(player, "SyncInventory", getSnapshot(player))
end

function InventoryServiceServer.init(): ()
	for _, player in ipairs(Players:GetPlayers()) do
		getInventory(player)
	end

	Players.PlayerAdded:Connect(function(player)
		getInventory(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerInventories[player] = nil
	end)
end

function InventoryServiceServer.GetSnapshot(player: Player): InventorySnapshot
	return getSnapshot(player)
end

function InventoryServiceServer.GetEntry(player: Player, entryId: string): InventoryEntry?
	local inventory = getInventory(player)
	local entry = inventory.Entries[entryId]
	if not entry then
		return nil
	end

	return cloneInventoryEntry(entry)
end

function InventoryServiceServer.Sync(player: Player): ()
	syncInventory(player)
end

function InventoryServiceServer.AddStackableItem(
	player: Player,
	itemKind: string,
	stackKey: string,
	serializedData: { [string]: any },
	quantity: number,
	maxStack: number?,
	storageSection: string?
): { string }
	local remaining = math.max(0, math.floor(quantity))
	local resolvedMaxStack = clampMaxStack(maxStack)
	local resolvedStorageSection = if type(storageSection) == "string" and storageSection ~= ""
		then storageSection
		else DEFAULT_STORAGE_SECTION
	local normalizedItemKind = if itemKind == "Item" then "Consumable" else itemKind
	local inventory = getInventory(player)
	local changedEntryIds = {}

	if remaining <= 0 then
		return changedEntryIds
	end

	for entryId, entry in pairs(inventory.Entries) do
		if remaining <= 0 then
			break
		end

		if entry.ItemKind == normalizedItemKind
			and entry.StorageSection == resolvedStorageSection
			and entry.StackKey == stackKey
			and entry.Quantity < entry.MaxStack then
			local amountToAdd = math.min(remaining, entry.MaxStack - entry.Quantity)
			entry.Quantity += amountToAdd
			remaining -= amountToAdd
			table.insert(changedEntryIds, entryId)
		end
	end

	while remaining > 0 do
		local amountToAdd = math.min(remaining, resolvedMaxStack)
		local entry = createEntry(normalizedItemKind, resolvedStorageSection, stackKey, amountToAdd, resolvedMaxStack, serializedData)
		inventory.Entries[entry.EntryId] = entry
		remaining -= amountToAdd
		table.insert(changedEntryIds, entry.EntryId)
	end

	syncInventory(player)
	return changedEntryIds
end

function InventoryServiceServer.AddSerializedWeapon(
	player: Player,
	serializedWeapon: SerializedWeaponData,
	storageSection: string?
): string
	local inventory = getInventory(player)
	local resolvedStorageSection = if type(storageSection) == "string" and storageSection ~= ""
		then storageSection
		else DEFAULT_STORAGE_SECTION
	local entry = createEntry(
		"Weapon",
		resolvedStorageSection,
		"Weapon:" .. serializedWeapon.InstanceId,
		1,
		WEAPON_MAX_STACK,
		serializedWeapon :: any
	)
	inventory.Entries[entry.EntryId] = entry
	syncInventory(player)
	return entry.EntryId
end

function InventoryServiceServer.AddWeaponFromPath(player: Player, weaponPath: string, storageSection: string?): string
	local weapon = EquipmentServiceServer.CreateWeaponFromDatabase(weaponPath)
	return InventoryServiceServer.AddSerializedWeapon(player, serializeWeapon(weapon), storageSection)
end

function InventoryServiceServer.RemoveEntry(player: Player, entryId: string, quantity: number?): boolean
	local inventory = getInventory(player)
	local entry = inventory.Entries[entryId]
	if not entry then
		return false
	end

	local amountToRemove = quantity and math.floor(quantity) or entry.Quantity
	if amountToRemove >= entry.Quantity then
		inventory.Entries[entryId] = nil
	else
		entry.Quantity -= math.max(0, amountToRemove)
	end

	syncInventory(player)
	return true
end

function InventoryServiceServer.GetStackQuantity(
	player: Player,
	itemKind: string,
	stackKey: string,
	storageSection: string?
): number
	local total = 0
	for _, entry in ipairs(getMatchingEntries(player, itemKind, stackKey, storageSection)) do
		total += entry.Quantity
	end
	return total
end

function InventoryServiceServer.HasStackQuantity(
	player: Player,
	itemKind: string,
	stackKey: string,
	quantity: number,
	storageSection: string?
): boolean
	local requiredQuantity = math.max(0, math.floor(quantity))
	if requiredQuantity <= 0 then
		return true
	end

	return InventoryServiceServer.GetStackQuantity(player, itemKind, stackKey, storageSection) >= requiredQuantity
end

function InventoryServiceServer.ConsumeStackQuantity(
	player: Player,
	itemKind: string,
	stackKey: string,
	quantity: number,
	storageSection: string?
): boolean
	local requiredQuantity = math.max(0, math.floor(quantity))
	if requiredQuantity <= 0 then
		return true
	end
	if not InventoryServiceServer.HasStackQuantity(player, itemKind, stackKey, requiredQuantity, storageSection) then
		return false
	end

	local inventory = getInventory(player)
	local remaining = requiredQuantity
	for _, entry in ipairs(getMatchingEntries(player, itemKind, stackKey, storageSection)) do
		if remaining <= 0 then
			break
		end

		local amountToRemove = math.min(remaining, entry.Quantity)
		if amountToRemove >= entry.Quantity then
			inventory.Entries[entry.EntryId] = nil
		else
			entry.Quantity -= amountToRemove
		end
		remaining -= amountToRemove
	end

	syncInventory(player)
	return true
end

function InventoryServiceServer.GetCoins(player: Player): number
	return InventoryServiceServer.GetStackQuantity(player, COIN_ITEM_KIND, COIN_STACK_KEY)
end

function InventoryServiceServer.HasCoins(player: Player, quantity: number): boolean
	return InventoryServiceServer.HasStackQuantity(player, COIN_ITEM_KIND, COIN_STACK_KEY, quantity)
end

function InventoryServiceServer.ConsumeCoins(player: Player, quantity: number): boolean
	return InventoryServiceServer.ConsumeStackQuantity(player, COIN_ITEM_KIND, COIN_STACK_KEY, quantity)
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "RequestInventory" then
		syncInventory(player)
	end
end)

return table.freeze(InventoryServiceServer)
