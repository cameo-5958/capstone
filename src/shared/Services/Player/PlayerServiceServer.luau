--!strict
-- A simple Service that keeps
-- track of players and runs personalized
-- methods

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

local PlayerServiceServer = {}

type Entity = EntityTypes.Entity

-- Store player Characters here
local PlayerCharacters: { [string]: Entity } = {}

-- Player added method
local function PlayerAdded(player: Player)
	-- Wait for character to load and store it
	local character = player.Character or player.CharacterAdded:Wait()
	
	-- Create an Entity associated with the player
	local entity = Entity.new(character, player.Name)

	PlayerCharacters[player.Name] = entity

	-- Do any additional setup here
end

-- Player removing method
local function PlayerRemoving(player: Player)
	-- Remove player from the table
	PlayerCharacters[player.Name] = nil

	-- Do any additional cleanup here
end

-- Connect player added and removing events
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

for _, player in pairs(Players:GetPlayers()) do
	PlayerAdded(player)
end

-- Method that returns list of players for use in
-- other Services
function PlayerServiceServer.GetPlayers(): { [string]: Entity }
	return PlayerCharacters
end

return table.freeze(PlayerServiceServer)
