--!strict
-- Mostly an utility module

-- Grab API endpoint
local API: RemoteEvent = script.Parent:WaitForChild("EnemyEndpoint")

-- Require
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
type Entity = EntityTypes.Entity

local __Enemies: {
	[string]: Entity,
} = {}

-- Public API
local Enemies = {}

-- API Handshakes
API.OnClientEvent:Connect(function(ds: { [string]: { [string]: Entity } })
	-- Delay the task to ensure that the models are all
	-- loaded in
	task.delay(0.5, function()
		-- Create
		for uuid, ent in pairs(ds["Create"]) do
			-- Cast to Entity to give functionality back
			__Enemies[uuid] = Entity.Inflate(ent)
		end
	end)
end)

-- Find closest
function Enemies.GetClosest(pos: Vector3, sight: number?)
	local closest = ""
	local closestDistance = sight or 64

	for uuid, ent in pairs(__Enemies) do
		-- Find the distance between pos and
		-- ent location
		local dist = (ent.RootPart.Position - pos).Magnitude

		if dist < closestDistance then
			closestDistance = dist
			closest = uuid
		end
	end

	return __Enemies[closest]
end

return table.freeze(Enemies)
