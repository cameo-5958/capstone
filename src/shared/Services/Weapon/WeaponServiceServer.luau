--!strict

local endpoint = script.Parent:FindFirstChild("WeaponEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "WeaponEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipmentServiceServer = require(ReplicatedStorage.Services.Equipment.EquipmentServiceServer)
local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
local WorldServiceServer: any
local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local Weapon = require(ReplicatedStorage.Classes.Weapon.Weapon)
local WeaponTypes = require(ReplicatedStorage.Classes.Weapon.WeaponTypes)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityTypes.Entity
type WeaponType = WeaponTypes.Weapon

local WeaponServiceServer = {}
local EQUIPPED_WEAPON_SOURCE = "weapon:equipped"
local PRIMARY_WEAPON_SLOT = 1
local LEGACY_MAX_WEAPON_SLOTS = 4
local DEFAULT_PLAYER_LOADOUT = {
	"Sword.Rookie",
}
local EquippedWeaponPassiveIds = setmetatable({}, { __mode = "k" }) :: { [Entity]: string? }

local PlayerEntities: { [Player]: Entity } = {}

local function getWorldServiceServer()
	if not WorldServiceServer then
		WorldServiceServer = require(ReplicatedStorage.Services.World.WorldServiceServer)
	end
	return WorldServiceServer
end

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

	return nil
end

local function resolveWeaponIcon(weaponId: string?): string?
	if type(weaponId) ~= "string" or weaponId == "" then
		return nil
	end

	local database = ReplicatedStorage:FindFirstChild("Database")
	if not database then
		return nil
	end

	local weapons = database:FindFirstChild("Weapons")
	if not weapons then
		return nil
	end

	local current: Instance = weapons
	for _, part in ipairs(weaponId:split(".")) do
		local nextNode = current:FindFirstChild(part)
		if not nextNode then
			return nil
		end
		current = nextNode
	end

	local dataModule = current:FindFirstChild("Data")
	if not dataModule or not dataModule:IsA("ModuleScript") then
		return nil
	end

	local ok, data = pcall(require, dataModule)
	if not ok or type(data) ~= "table" then
		return nil
	end

	local icon = data.Icon
	if type(icon) == "string" and icon ~= "" then
		return icon
	end

	return nil
end

local function createStarterWeapon()
	return Weapon.new(
		"Starter Sword",
		12,
		{
			Strength = 4,
			PhysicalAttack = 6,
			Speed = 1,
		},
		3,
		function(_, entity: Entity)
			local restored = math.min(entity:GetStat("MaxHealth"), entity:GetStat("Health") + 15)
			entity:SetStat("Health", restored)
		end,
		nil,
		"StarterSword",
		nil,
		nil,
		"Sword",
		{
			MaxDashRange = 2.5,
			SwingRange = 4.5,
		}
	)
end

local function SerializeEquippedWeapon(weapon: WeaponType?)
	if not weapon then
		return nil
	end

	return {
		ItemKind = "Weapon",
		Name = weapon.Name,
		Rarity = weapon.Rarity,
		Class = weapon.Class,
		Type = weapon.Type,
		AttackContext = weapon:GetAttackContext(),
		InstanceId = weapon.UUID,
		WeaponId = weapon.WeaponId,
		BaseDamage = weapon.BaseDamage,
		GrantedStats = table.clone(weapon.GrantedStats),
		Weight = weapon.Weight,
		Icon = resolveWeaponIcon(weapon.WeaponId),
		HasPassive = weapon.WeaponPassive ~= nil or #weapon.PassiveDetails > 0,
		HasAbility = weapon.WeaponAbility ~= nil,
		AbilityCooldown = weapon.AbilityCooldown,
		PassiveDetails = cloneSerializable(weapon.PassiveDetails) or {},
	}
end

local function SerializeLoadoutSlot(entity: Entity, slot: number): { [string]: any }
	local weapon = entity:GetToolbarWeapon(slot)
	local data = SerializeEquippedWeapon(weapon) or {}
	data.Slot = slot
	data.IsEquipped = entity:GetEquippedIndex() == slot
	return data
end

local function SerializeLoadout(entity: Entity): { [string]: any }
	return {
		EquippedIndex = entity:GetEquippedIndex(),
		Slots = {
			SerializeLoadoutSlot(entity, PRIMARY_WEAPON_SLOT),
		},
	}
end

local function ApplyEquippedWeaponStats(entity: Entity): ()
	entity:RemoveModifiersFromSource(EQUIPPED_WEAPON_SOURCE)

	local previousPassiveId = EquippedWeaponPassiveIds[entity]
	if previousPassiveId then
		entity:RemoveAttackModifierById(previousPassiveId)
		EquippedWeaponPassiveIds[entity] = nil
	end

	local equippedWeapon = entity:GetEquippedWeapon()
	if not equippedWeapon then
		return
	end

	for statName, statValue in pairs(equippedWeapon.GrantedStats) do
		entity:AddModifier(
			statName,
			Modifier.new(
				("%s:%s"):format(EQUIPPED_WEAPON_SOURCE, statName),
				"BaseFlat",
				statValue,
				EQUIPPED_WEAPON_SOURCE
			)
		)
	end

	if equippedWeapon.WeaponPassive then
		entity:AddAttackModifier(equippedWeapon.WeaponPassive)
		EquippedWeaponPassiveIds[entity] = equippedWeapon.WeaponPassive.Id
	end
end

local function FireWeaponSwapHook(
	entity: Entity,
	previousWeapon: WeaponType?,
	nextWeapon: WeaponType?,
	previousSlot: number?,
	nextSlot: number?
): ()
	if previousWeapon == nextWeapon and previousSlot == nextSlot then
		return
	end

	entity:TriggerOnWeaponSwap({
		Entity = entity,
		PreviousWeapon = previousWeapon,
		NextWeapon = nextWeapon,
		PreviousSlot = previousSlot,
		NextSlot = nextSlot,
	})
end

local function FindExistingToolbarSlotForInventoryWeapon(entity: Entity, serializedWeapon: { [string]: any }): number?
	local instanceId = serializedWeapon.InstanceId
	if type(instanceId) == "string" and instanceId ~= "" then
		for slot = 1, LEGACY_MAX_WEAPON_SLOTS do
			local weapon = entity:GetToolbarWeapon(slot)
			if weapon and weapon.UUID == instanceId then
				return slot
			end
		end
	end

	local weaponId = serializedWeapon.WeaponId
	if type(weaponId) ~= "string" or weaponId == "" then
		return nil
	end

	for slot = 1, LEGACY_MAX_WEAPON_SLOTS do
		local weapon = entity:GetToolbarWeapon(slot)
		if weapon and weapon.WeaponId == weaponId then
			return slot
		end
	end

	return nil
end

local function NormalizeSingleWeaponSlot(entity: Entity): ()
	local primaryWeapon = entity:GetToolbarWeapon(PRIMARY_WEAPON_SLOT)
	if not primaryWeapon then
		for slot = PRIMARY_WEAPON_SLOT + 1, LEGACY_MAX_WEAPON_SLOTS do
			local legacyWeapon = entity:GetToolbarWeapon(slot)
			if legacyWeapon then
				EquipmentServiceServer.SwapToolbarSlots(entity, slot, PRIMARY_WEAPON_SLOT)
				primaryWeapon = entity:GetToolbarWeapon(PRIMARY_WEAPON_SLOT)
				break
			end
		end
	end

	for slot = PRIMARY_WEAPON_SLOT + 1, LEGACY_MAX_WEAPON_SLOTS do
		if entity:GetToolbarWeapon(slot) ~= nil then
			EquipmentServiceServer.ClearToolbarSlot(entity, slot)
		end
	end

	if entity:GetToolbarWeapon(PRIMARY_WEAPON_SLOT) ~= nil then
		entity:SetEquippedIndex(PRIMARY_WEAPON_SLOT)
	else
		entity:SetEquippedIndex(nil)
	end
end

local function hasToolbarWeapons(entity: Entity): boolean
	for slot = 1, LEGACY_MAX_WEAPON_SLOTS do
		if entity:GetToolbarWeapon(slot) ~= nil then
			return true
		end
	end

	return false
end

local function ensureDefaultPlayerLoadout(entity: Entity): ()
	if hasToolbarWeapons(entity) then
		return
	end

	EquipmentServiceServer.ApplyLoadout(entity, DEFAULT_PLAYER_LOADOUT)
end

function WeaponServiceServer.RegisterEntity(player: Player, entity: Entity): ()
	PlayerEntities[player] = entity
	ensureDefaultPlayerLoadout(entity)
	NormalizeSingleWeaponSlot(entity)
	EquipmentServiceServer.RestoreEquippedWeaponVisual(entity)
	ApplyEquippedWeaponStats(entity)
end

function WeaponServiceServer.UnregisterEntity(player: Player): ()
	PlayerEntities[player] = nil
end

function WeaponServiceServer.SyncEquippedWeapon(player: Player): ()
	local entity = PlayerEntities[player]
	if not entity then
		return
	end

	ApplyEquippedWeaponStats(entity)

	API:FireClient(player, "SyncEquippedWeapon", SerializeEquippedWeapon(entity:GetEquippedWeapon()))
	API:FireClient(player, "SyncLoadout", SerializeLoadout(entity))
end

function WeaponServiceServer.SyncLoadout(player: Player): ()
	local entity = PlayerEntities[player]
	if not entity then
		return
	end

	API:FireClient(player, "SyncLoadout", SerializeLoadout(entity))
end

function WeaponServiceServer.CreateStarterWeapon()
	return createStarterWeapon()
end

function WeaponServiceServer.SetEquippedSlot(player: Player, _slot: number?)
	local entity = PlayerEntities[player]
	if not entity then
		return
	end

	NormalizeSingleWeaponSlot(entity)

	local previousSlot = entity:GetEquippedIndex()
	local previousWeapon = entity:GetEquippedWeapon()
	if entity:GetToolbarWeapon(PRIMARY_WEAPON_SLOT) ~= nil then
		entity:SetEquippedIndex(PRIMARY_WEAPON_SLOT)
	else
		entity:SetEquippedIndex(nil)
	end

	FireWeaponSwapHook(entity, previousWeapon, entity:GetEquippedWeapon(), previousSlot, entity:GetEquippedIndex())
	EquipmentServiceServer.RestoreEquippedWeaponVisual(entity)
	WeaponServiceServer.SyncEquippedWeapon(player)
end

function WeaponServiceServer.ClearToolbarSlot(player: Player, slot: number?): ()
	local entity = PlayerEntities[player]
	if not entity or type(slot) ~= "number" or slot < 1 or slot > LEGACY_MAX_WEAPON_SLOTS then
		return
	end
	if slot == PRIMARY_WEAPON_SLOT then
		return
	end

	local previousSlot = entity:GetEquippedIndex()
	local previousWeapon = entity:GetEquippedWeapon()
	EquipmentServiceServer.ClearToolbarSlot(entity, slot)
	if entity:GetEquippedIndex() == slot then
		entity:SetEquippedIndex(nil)
	end

	FireWeaponSwapHook(entity, previousWeapon, entity:GetEquippedWeapon(), previousSlot, entity:GetEquippedIndex())
	EquipmentServiceServer.RestoreEquippedWeaponVisual(entity)
	WeaponServiceServer.SyncEquippedWeapon(player)
end

function WeaponServiceServer.EquipInventoryEntry(player: Player, entryId: string, _targetSlot: number?): boolean
	local entity = PlayerEntities[player]
	if not entity then
		return false
	end

	if type(entryId) ~= "string" or entryId == "" then
		return false
	end

	local entry = InventoryServiceServer.GetEntry(player, entryId)
	if not entry or entry.ItemKind ~= "Weapon" then
		return false
	end

	local serializedWeapon = entry.Data
	NormalizeSingleWeaponSlot(entity)

	local existingSlot = FindExistingToolbarSlotForInventoryWeapon(entity, serializedWeapon)
	if existingSlot == PRIMARY_WEAPON_SLOT then
		WeaponServiceServer.SetEquippedSlot(player, PRIMARY_WEAPON_SLOT)
		return true
	end

	local previousSlot = entity:GetEquippedIndex()
	local previousWeapon = entity:GetEquippedWeapon()

	if existingSlot and existingSlot ~= PRIMARY_WEAPON_SLOT then
		EquipmentServiceServer.ClearToolbarSlot(entity, existingSlot)
	end

	EquipmentServiceServer.AssignSerializedToolbarWeapon(entity, serializedWeapon, PRIMARY_WEAPON_SLOT)
	entity:SetEquippedIndex(PRIMARY_WEAPON_SLOT)
	NormalizeSingleWeaponSlot(entity)

	FireWeaponSwapHook(entity, previousWeapon, entity:GetEquippedWeapon(), previousSlot, entity:GetEquippedIndex())
	EquipmentServiceServer.RestoreEquippedWeaponVisual(entity)
	WeaponServiceServer.SyncEquippedWeapon(player)
	return true
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "UseAbility" then
		if not getWorldServiceServer().IsMatchStarted() then
			return
		end

		local entity = PlayerEntities[player]
		if not entity then
			return
		end

		local equipped = entity:GetEquippedWeapon()
		if not equipped then
			return
		end

		equipped:UseRightClick(entity, payload or {})
	elseif action == "EquipSlot" then
		if getWorldServiceServer().IsPlayerWardrobeLocked(player) then
			return
		end
		WeaponServiceServer.SetEquippedSlot(player, payload and payload.Slot or nil)
	elseif action == "EquipInventoryEntry" then
		if getWorldServiceServer().IsPlayerWardrobeLocked(player) then
			return
		end
		WeaponServiceServer.EquipInventoryEntry(
			player,
			payload and payload.EntryId or "",
			payload and payload.Slot or nil
		)
	elseif action == "UnequipSlot" then
		if getWorldServiceServer().IsPlayerWardrobeLocked(player) then
			return
		end
		WeaponServiceServer.ClearToolbarSlot(player, payload and payload.Slot or nil)
	elseif action == "Unequip" then
		if getWorldServiceServer().IsPlayerWardrobeLocked(player) then
			return
		end
		WeaponServiceServer.SetEquippedSlot(player, nil)
	elseif action == "RequestEquippedWeapon" then
		WeaponServiceServer.SyncEquippedWeapon(player)
	elseif action == "RequestLoadout" then
		WeaponServiceServer.SyncLoadout(player)
	end
end)

return table.freeze(WeaponServiceServer)
