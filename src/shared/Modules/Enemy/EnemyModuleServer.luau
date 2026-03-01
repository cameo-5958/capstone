--!strict
-- Creates and handles enemies

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

-- Use Entities class
type Entity = EntityTypes.Entity

-- Load Entity registry folder
local Database = ReplicatedStorage:WaitForChild("Database")
local EnemiesDatabase = Database.Enemies

-- Create RemoteEvent for Enemy API
local API = Instance.new("RemoteEvent")
API.Parent = script.Parent
API.Name = "EnemyEndpoint"

-- Create Folder for enemies to be stored in
local EnemyFolder = workspace:FindFirstChild("EntitiesFolder") or Instance.new("Folder")
EnemyFolder.Name = "EntitiesFolder"
EnemyFolder.Parent = workspace

local __Enemies: {
	[string]: Entity, -- UUID -> Entity

	-- Methods
} = {}

local Enemies = {}

-- When players are added, send all the
-- Entities as deserialized data
Players.PlayerAdded:Connect(function(player)
	API:FireClient(player, {
		["Create"] = __Enemies,
	})
end)

-- Entity creation
local default = {
	TrueDefense = 0,
	Strength = 0,
	CritRate = 0,
	CritDamage = 0,
	PhysicalAttack = 0,
	MagicalAttack = 0,
}
function Enemies.Spawn(e: string, SpawnBlock: Part): ()
	-- Grab enemy's data from the database
	-- Split Enemy into multiple parts
	local EnemyPath = e:split(".")
	local Enemy = EnemiesDatabase

	for _, part in pairs(EnemyPath) do
		Enemy = Enemy:WaitForChild(part)
	end

	-- Require the data to create the entity
	local data = require(Enemy.Data) :: any
	local model = Enemy.Model:Clone() :: Model

	model.Parent = EnemyFolder

	-- Create the entity here
	local entity = Entity.new(model, data.Name)
	entity.RootPart:PivotTo(SpawnBlock.CFrame)

	-- Set default enemy stats
	for key, value in pairs(default) do
		entity.__Stats[key] = value
	end

	-- Set enemy specific stats
	for key, value in pairs(data) do
		if entity[key] then
			entity[key] = value
		else
			entity.__Stats[key] = value
		end
	end

	-- Add to the database
	__Enemies[entity.UUID] = entity

	-- Send the entity to all clients
	API:FireAllClients({
		["Create"] = {
			[entity.UUID] = entity,
		},
	})
end

return Enemies
