--!strict

local API = script.Parent:WaitForChild("WeaponEndpoint") :: RemoteEvent

local WeaponServiceClient = {}

function WeaponServiceClient.UseAbility(payload: { [string]: any }?): ()
	API:FireServer("UseAbility", payload or {})
end

return table.freeze(WeaponServiceClient)
