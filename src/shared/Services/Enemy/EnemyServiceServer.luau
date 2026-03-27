--!strict
-- Creates and handles enemies

-- Create RemoteEvent for Enemy API
local API = Instance.new("RemoteEvent")
API.Parent = script.Parent
API.Name = "EnemyEndpoint"

-- Create RemoteEvent for Enemy API
local Handler = Instance.new("RemoteEvent")
Handler.Parent = script.Parent
Handler.Name = "EnemyHandler"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Brains = require(ReplicatedStorage.Classes.Enemy.Brains)
local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local Movement = require(ReplicatedStorage.Classes.Entity.EntityMovement)
local CollisionServiceServer = require(ReplicatedStorage.Services.Collision.CollisionServiceServer)
local DefaultAnimations = require(ReplicatedStorage.Database.Enemies.Default.Animations)

-- Use Entities class
type Entity = EntityTypes.Entity

-- Load Entity registry folder
local Database = ReplicatedStorage:WaitForChild("Database")
local EnemiesDatabase = Database.Enemies

-- Create Folder for enemies to be stored in
local EnemyFolder = workspace:WaitForChild("EntitiesFolder")
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
	local data = require(Enemy.Data) :: { ["Name"]: string, string: any }
	local model = Enemy.Model:Clone() :: Model
	local mergedAnimations = table.clone(DefaultAnimations)
	for key, value in pairs(data.__Animations or {}) do
		mergedAnimations[key] = value
	end

	model.Parent = EnemyFolder
	CollisionServiceServer.AssignModel(model, "Enemy")

	-- Create the entity here
	local entity = Entity.new(model, data.Name)
	model.Name = entity.UUID
	entity.RootPart:PivotTo(SpawnBlock.CFrame)
	entity.__Animations = mergedAnimations

	-- Set default enemy stats
	for key, value in pairs(default) do
		entity:SetStat(key, value)
	end

	-- Set enemy specific stats
	for key, value in pairs(data) do
		if key == "__Stats" then
			for statName, statValue in pairs(value) do
				entity:SetStat(statName, statValue)
			end
			continue
		end
		if key == "__Animations" then
			continue
		end

		-- Check type of entity[key]
		if typeof(entity[key]) == typeof(table) then
			-- Add them one by one
			for k, v in pairs(value) do
				entity[key][k] = v
			end
		else
			entity[key] = value
		end
	end

	print(entity)

	-- Add to the database
	__Enemies[entity.UUID] = entity

	-- Give it its engines
	local movementEngine = Movement.new(entity)
	local brain = Brains.Aggressive(movementEngine, 32)

	-- Start the brain loop
	brain:Go()

	-- Send the entity to all clients
	API:FireAllClients({
		["Create"] = {
			[entity.UUID] = entity,
		},
	})
end

function Enemies.GetClosest(position: Vector3, sight: number?): Entity?
	local closest: Entity? = nil
	local closestDistance = sight or math.huge

	for _, entity in pairs(__Enemies) do
		if entity:IsAlive() then
			local distance = (entity.RootPart.Position - position).Magnitude
			if distance < closestDistance then
				closest = entity
				closestDistance = distance
			end
		end
	end

	return closest
end

function Enemies.GetByUUID(uuid: string): Entity?
	return __Enemies[uuid]
end

return Enemies
