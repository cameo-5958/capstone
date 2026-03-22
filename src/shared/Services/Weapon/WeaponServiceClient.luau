--!strict

local API = script.Parent:WaitForChild("WeaponEndpoint") :: RemoteEvent

local WeaponServiceClient = {}

local EquippedWeaponData: { [string]: any }? = nil

API.OnClientEvent:Connect(function(action: string, payload: { [string]: any }?)
	if action == "SyncEquippedWeapon" then
		EquippedWeaponData = payload
	end
end)

function WeaponServiceClient.UseAbility(payload: { [string]: any }?): ()
	API:FireServer("UseAbility", payload or {})
end

function WeaponServiceClient.GetEquippedWeaponData(): { [string]: any }?
	return EquippedWeaponData
end

return table.freeze(WeaponServiceClient)
