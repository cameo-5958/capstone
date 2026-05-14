--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)
local API = script.Parent:WaitForChild("WeaponEndpoint") :: RemoteEvent

local WeaponServiceClient = {}

local EquippedWeaponData: { [string]: any }? = nil
local LoadoutData: { [string]: any } = {
	EquippedIndex = nil,
	Slots = {
		{ Slot = 1, IsEquipped = false },
	},
}
local EquippedWeaponChanged = Signal.new()
local LoadoutChanged = Signal.new()
local HasReceivedInitialLoadout = false

API.OnClientEvent:Connect(function(action: string, payload: { [string]: any }?)
	if action == "SyncEquippedWeapon" then
		EquippedWeaponData = payload
		EquippedWeaponChanged:Fire(payload)
	elseif action == "SyncLoadout" then
		LoadoutData = payload or LoadoutData
		HasReceivedInitialLoadout = true
		LoadoutChanged:Fire(LoadoutData)
	end
end)

task.defer(function()
	API:FireServer("RequestEquippedWeapon", {})
	API:FireServer("RequestLoadout", {})
end)

function WeaponServiceClient.UseAbility(payload: { [string]: any }?): ()
	API:FireServer("UseAbility", payload or {})
end

function WeaponServiceClient.EquipSlot(slot: number?)
	API:FireServer("EquipSlot", {
		Slot = slot,
	})
end

function WeaponServiceClient.EquipInventoryEntry(entryId: string): ()
	API:FireServer("EquipInventoryEntry", {
		EntryId = entryId,
	})
end

function WeaponServiceClient.EquipInventoryEntryToSlot(entryId: string, slot: number): ()
	API:FireServer("EquipInventoryEntry", {
		EntryId = entryId,
		Slot = slot,
	})
end

function WeaponServiceClient.Unequip()
	API:FireServer("Unequip", {})
end

function WeaponServiceClient.UnequipSlot(slot: number): ()
	API:FireServer("UnequipSlot", {
		Slot = slot,
	})
end

function WeaponServiceClient.GetEquippedWeaponData(): { [string]: any }?
	return EquippedWeaponData
end

function WeaponServiceClient.GetEquippedWeaponChangedSignal()
	return EquippedWeaponChanged
end

function WeaponServiceClient.RequestEquippedWeapon(): ()
	API:FireServer("RequestEquippedWeapon", {})
end

function WeaponServiceClient.RequestLoadout(): ()
	API:FireServer("RequestLoadout", {})
end

function WeaponServiceClient.GetLoadoutData(): { [string]: any }
	return LoadoutData
end

function WeaponServiceClient.GetLoadoutChangedSignal()
	return LoadoutChanged
end

function WeaponServiceClient.HasReceivedInitialLoadout(): boolean
	return HasReceivedInitialLoadout
end

return table.freeze(WeaponServiceClient)
