--!strict
-- A simple Service that keeps
-- track of players and runs personalized
-- methods

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local CollisionServiceServer = require(ReplicatedStorage.Services.Collision.CollisionServiceServer)
local EquipmentServiceServer = require(ReplicatedStorage.Services.Equipment.EquipmentServiceServer)
local WeaponServiceServer = require(ReplicatedStorage.Services.Weapon.WeaponServiceServer)
local PlayerConfig = require(ReplicatedStorage.Database.Players.Default.Data)

local PlayerServiceServer = {}

type Entity = EntityTypes.Entity

-- Store player Characters here
local PlayerCharacters: { [string]: Entity } = {}

local function BindCharacter(player: Player, character: Model): Entity
	local animateScript = character:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end

	CollisionServiceServer.AssignModel(character, "Player")

	local entity = PlayerCharacters[player.Name]

	if entity then
		entity.Character = character
		entity.RootPart = character.PrimaryPart or character:WaitForChild("HumanoidRootPart") :: BasePart
	else
		entity = Entity.new(character, player.Name)
		for key, value in pairs(PlayerConfig) do
			if typeof(entity[key]) == typeof(table) then
				for nestedKey, nestedValue in pairs(value) do
					entity[key][nestedKey] = nestedValue
				end
			else
				entity[key] = value
			end
		end
		PlayerCharacters[player.Name] = entity
	end

	WeaponServiceServer.RegisterEntity(player, entity)
	EquipmentServiceServer.GiveDefaultLoadout(entity)
	WeaponServiceServer.SyncEquippedWeapon(player)

	return entity
end

-- Player added method
local function PlayerAdded(player: Player)
	-- Wait for character to load and store it
	local character = player.Character or player.CharacterAdded:Wait()
	BindCharacter(player, character)
	player.CharacterAdded:Connect(function(nextCharacter)
		BindCharacter(player, nextCharacter)
	end)

	-- Do any additional setup here
end

-- Player removing method
local function PlayerRemoving(player: Player)
	-- Remove player from the table
	PlayerCharacters[player.Name] = nil
	WeaponServiceServer.UnregisterEntity(player)

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

function PlayerServiceServer.GetEntity(player: Player): Entity?
	return PlayerCharacters[player.Name]
end

function PlayerServiceServer.GetEntityFromCharacter(character: Model): Entity?
	for _, entity in pairs(PlayerCharacters) do
		if entity.Character == character then
			return entity
		end
	end

	return nil
end

return table.freeze(PlayerServiceServer)
