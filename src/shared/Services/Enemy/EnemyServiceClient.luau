--!strict
-- Mostly an utility module

-- Grab API endpoints
local API: RemoteEvent = script.Parent:WaitForChild("EnemyEndpoint")
local Handler: RemoteEvent = script.Parent:WaitForChild("EnemyHandler")

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

-- Handle movement etc.
Handler.OnClientEvent:Connect(function(action: string, data: { [string]: any })
	if action == "Move" then
		local ent = __Enemies[data.UUID]
		if ent and ent.Character and ent.Character:FindFirstChild("Humanoid") then
			(ent.Character:FindFirstChild("Humanoid") :: Humanoid):MoveTo(data.Position)
		end
	elseif action == "Pivot" then
		local ent = __Enemies[data.UUID]
		if ent and ent.Character and ent.Character.PrimaryPart then
			ent.Character.PrimaryPart:PivotTo(data.CFrame)
		end
	end
end)

return table.freeze(Enemies)
