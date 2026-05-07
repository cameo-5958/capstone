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
local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local Weapon = require(ReplicatedStorage.Classes.Weapon.Weapon)
local WeaponTypes = require(ReplicatedStorage.Classes.Weapon.WeaponTypes)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityTypes.Entity
type WeaponType = WeaponTypes.Weapon

local WeaponServiceServer = {}
local EQUIPPED_WEAPON_SOURCE = "weapon:equipped"
local EquippedWeaponPassiveIds = setmetatable({}, { __mode = "k" }) :: { [Entity]: string? }

local PlayerEntities: { [Player]: Entity } = {}
local PlayerConnections: { [Player]: { RBXScriptConnection } } = {}

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
		HasPassive = weapon.WeaponPassive ~= nil or #weapon.PassiveDetails > 0,
		HasAbility = weapon.WeaponAbility ~= nil,
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
	local slots = {}
	for slot = 1, 4 do
		slots[slot] = SerializeLoadoutSlot(entity, slot)
	end

	return {
		EquippedIndex = entity:GetEquippedIndex(),
		Slots = slots,
	}
end

local function DisconnectPlayerConnections(player: Player)
	local connections = PlayerConnections[player]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	PlayerConnections[player] = nil
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
		entity:AddModifier(statName, Modifier.new(
			("%s:%s"):format(EQUIPPED_WEAPON_SOURCE, statName),
			"BaseFlat",
			statValue,
			EQUIPPED_WEAPON_SOURCE
		))
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
		for slot = 1, 4 do
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
	for slot = 1, 4 do
		local weapon = entity:GetToolbarWeapon(slot)
		if weapon and weapon.WeaponId == weaponId then
			return slot
		end
	end

	return nil
end

local function GetFirstEmptyToolbarSlot(entity: Entity): number
	for slot = 1, 4 do
		if entity:GetToolbarWeapon(slot) == nil then
			return slot
		end
	end

	return 4
end

local function IsCharacterDyingOrRemoved(character: Model): boolean
	if character.Parent == nil then
		return true
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health <= 0
end

function WeaponServiceServer.RegisterEntity(player: Player, entity: Entity): ()
	PlayerEntities[player] = entity
	DisconnectPlayerConnections(player)
	if entity:GetToolbarWeapon(1) ~= nil and entity:GetEquippedIndex() == nil then
		entity:SetEquippedIndex(1)
	end
	EquipmentServiceServer.RestoreToolbarTools(entity)
	ApplyEquippedWeaponStats(entity)

	local character = entity.Character
	PlayerConnections[player] = {
		character.ChildAdded:Connect(function(child)
			if not child:IsA("Tool") then
				return
			end

			local slot = child:GetAttribute("ToolbarSlot")
			if type(slot) ~= "number" then
				return
			end

			local previousSlot = entity:GetEquippedIndex()
			local previousWeapon = entity:GetEquippedWeapon()
			if entity:GetToolbarWeapon(slot) == nil then
				entity:SetEquippedIndex(nil)
			else
				entity:SetEquippedIndex(slot)
			end
			local equippedWeapon = entity:GetEquippedWeapon()
			FireWeaponSwapHook(entity, previousWeapon, equippedWeapon, previousSlot, entity:GetEquippedIndex())
			ApplyEquippedWeaponStats(entity)
			WeaponServiceServer.SyncEquippedWeapon(player)
		end),
		character.ChildRemoved:Connect(function(child)
			if not child:IsA("Tool") then
				return
			end

			local slot = child:GetAttribute("ToolbarSlot")
			if type(slot) ~= "number" then
				return
			end

			if IsCharacterDyingOrRemoved(character) then
				return
			end

			if entity:GetEquippedIndex() == slot then
				local previousWeapon = entity:GetEquippedWeapon()
				entity:SetEquippedIndex(nil)
				FireWeaponSwapHook(entity, previousWeapon, nil, slot, nil)
				ApplyEquippedWeaponStats(entity)
				WeaponServiceServer.SyncEquippedWeapon(player)
			end
		end),
	}
end

function WeaponServiceServer.UnregisterEntity(player: Player): ()
	DisconnectPlayerConnections(player)
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

function WeaponServiceServer.SetEquippedSlot(player: Player, slot: number?)
	local entity = PlayerEntities[player]
	if not entity then
		return
	end

	local previousSlot = entity:GetEquippedIndex()
	local previousWeapon = entity:GetEquippedWeapon()
	if slot == nil then
		entity:SetEquippedIndex(nil)
	else
		if entity:GetToolbarWeapon(slot) ~= nil then
			entity:SetEquippedIndex(slot)
		else
			entity:SetEquippedIndex(nil)
		end
	end

	FireWeaponSwapHook(entity, previousWeapon, entity:GetEquippedWeapon(), previousSlot, entity:GetEquippedIndex())
	WeaponServiceServer.SyncEquippedWeapon(player)
end

function WeaponServiceServer.ClearToolbarSlot(player: Player, slot: number?): ()
	local entity = PlayerEntities[player]
	if not entity or type(slot) ~= "number" or slot < 1 or slot > 4 then
		return
	end

	local previousSlot = entity:GetEquippedIndex()
	local previousWeapon = entity:GetEquippedWeapon()
	EquipmentServiceServer.ClearToolbarSlot(entity, slot)
	if entity:GetEquippedIndex() == slot then
		entity:SetEquippedIndex(nil)
	end

	FireWeaponSwapHook(entity, previousWeapon, entity:GetEquippedWeapon(), previousSlot, entity:GetEquippedIndex())
	WeaponServiceServer.SyncEquippedWeapon(player)
end

function WeaponServiceServer.EquipInventoryEntry(player: Player, entryId: string, targetSlot: number?): boolean
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
	if targetSlot ~= nil then
		if type(targetSlot) ~= "number" or targetSlot < 1 or targetSlot > 4 then
			return false
		end
		targetSlot = math.floor(targetSlot)
	end

	local existingSlot = FindExistingToolbarSlotForInventoryWeapon(entity, serializedWeapon)
	if existingSlot and (targetSlot == nil or targetSlot == existingSlot) then
		WeaponServiceServer.SetEquippedSlot(player, existingSlot)
		return true
	end

	targetSlot = targetSlot or GetFirstEmptyToolbarSlot(entity)
	local previousSlot = entity:GetEquippedIndex()
	local previousWeapon = entity:GetEquippedWeapon()

	if existingSlot and existingSlot ~= targetSlot then
		EquipmentServiceServer.SwapToolbarSlots(entity, existingSlot, targetSlot)
		entity:SetEquippedIndex(targetSlot)

		FireWeaponSwapHook(entity, previousWeapon, entity:GetEquippedWeapon(), previousSlot, targetSlot)
		WeaponServiceServer.SyncEquippedWeapon(player)
		return true
	end

	EquipmentServiceServer.AssignSerializedToolbarWeapon(entity, serializedWeapon, targetSlot)
	entity:SetEquippedIndex(targetSlot)

	FireWeaponSwapHook(entity, previousWeapon, entity:GetEquippedWeapon(), previousSlot, targetSlot)
	WeaponServiceServer.SyncEquippedWeapon(player)
	return true
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "UseAbility" then
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
		WeaponServiceServer.SetEquippedSlot(player, payload and payload.Slot or nil)
	elseif action == "EquipInventoryEntry" then
		WeaponServiceServer.EquipInventoryEntry(player, payload and payload.EntryId or "", payload and payload.Slot or nil)
	elseif action == "UnequipSlot" then
		WeaponServiceServer.ClearToolbarSlot(player, payload and payload.Slot or nil)
	elseif action == "Unequip" then
		WeaponServiceServer.SetEquippedSlot(player, nil)
	elseif action == "RequestEquippedWeapon" then
		WeaponServiceServer.SyncEquippedWeapon(player)
	elseif action == "RequestLoadout" then
		WeaponServiceServer.SyncLoadout(player)
	end
end)

return table.freeze(WeaponServiceServer)



