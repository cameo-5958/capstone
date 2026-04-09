--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)
local API = script.Parent:WaitForChild("WeaponEndpoint") :: RemoteEvent

local WeaponServiceClient = {}

local EquippedWeaponData: { [string]: any }? = nil
local EquippedWeaponChanged = Signal.new()

API.OnClientEvent:Connect(function(action: string, payload: { [string]: any }?)
	if action == "SyncEquippedWeapon" then
		EquippedWeaponData = payload
		EquippedWeaponChanged:Fire(payload)
	end
end)

function WeaponServiceClient.UseAbility(payload: { [string]: any }?): ()
	API:FireServer("UseAbility", payload or {})
end

function WeaponServiceClient.EquipSlot(slot: number?)
	API:FireServer("EquipSlot", {
		Slot = slot,
	})
end

function WeaponServiceClient.Unequip()
	API:FireServer("Unequip", {})
end

function WeaponServiceClient.GetEquippedWeaponData(): { [string]: any }?
	return EquippedWeaponData
end

function WeaponServiceClient.GetEquippedWeaponChangedSignal()
	return EquippedWeaponChanged
end

return table.freeze(WeaponServiceClient)
