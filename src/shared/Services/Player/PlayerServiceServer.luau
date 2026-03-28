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
type Connection = {
	Disconnect: (self: Connection) -> (),
}

-- Store player Characters here
local PlayerCharacters: { [string]: Entity } = {}
local PlayerStatConnections: { [string]: { Connection } } = {}
local STAT_NAMES = {
	"Health",
	"MaxHealth",
	"Defense",
	"Strength",
	"CritRate",
	"CritDamage",
	"Intelligence",
	"PhysicalAttack",
	"MagicalAttack",
	"PhysicalDamage",
	"MagicDamage",
	"Speed",
}

local endpoint = script.Parent:FindFirstChild("PlayerEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "PlayerEndpoint"
	endpoint.Parent = script.Parent
end
local API = endpoint :: RemoteEvent
local DASH_IFRAME_DURATION = 0.3
local DASH_IFRAME_COOLDOWN = 0.3
local PlayerNextDashIframeAt: { [string]: number } = {}

local function DisconnectStatConnections(playerName: string)
	local connections = PlayerStatConnections[playerName]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	PlayerStatConnections[playerName] = nil
end

local function SerializeStats(entity: Entity): { [string]: number }
	local stats: { [string]: number } = {}
	for _, statName in ipairs(STAT_NAMES) do
		stats[statName] = entity:GetStat(statName)
	end

	return stats
end

local function SyncStatsToClient(player: Player, entity: Entity)
	API:FireClient(player, "SyncStats", {
		Stats = SerializeStats(entity),
	})
end

local function BindStatReplication(player: Player, entity: Entity)
	DisconnectStatConnections(player.Name)

	local connections = {}
	for _, statName in ipairs(STAT_NAMES) do
		table.insert(connections, entity:GetStatChangedSignal(statName):Connect(function(newValue: number)
			API:FireClient(player, "SyncStat", {
				Stat = statName,
				Value = newValue,
			})
		end))
	end

	PlayerStatConnections[player.Name] = connections
end

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
		entity:SyncCharacterStats()
	else
		entity = Entity.new(character, player.Name)
		for key, value in pairs(PlayerConfig) do
			if key == "__Stats" then
				for statName, statValue in pairs(value) do
					entity:SetStat(statName, statValue)
				end
			elseif typeof(entity[key]) == typeof(table) then
				for nestedKey, nestedValue in pairs(value) do
					entity[key][nestedKey] = nestedValue
				end
			else
				entity[key] = value
			end
		end
		PlayerCharacters[player.Name] = entity
	end

	BindStatReplication(player, entity)
	SyncStatsToClient(player, entity)

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
	DisconnectStatConnections(player.Name)
	PlayerNextDashIframeAt[player.Name] = nil
	WeaponServiceServer.UnregisterEntity(player)

	-- Do any additional cleanup here
end

-- Connect player added and removing events
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

for _, player in pairs(Players:GetPlayers()) do
	PlayerAdded(player)
end

API.OnServerEvent:Connect(function(player: Player, action: string)
	local entity = PlayerCharacters[player.Name]
	if action == "RequestSnapshot" then
		if entity then
			SyncStatsToClient(player, entity)
		end
	elseif action == "RequestDashIFrames" then
		if not entity or not entity:IsAlive() then
			return
		end

		local now = workspace:GetServerTimeNow()
		if now < (PlayerNextDashIframeAt[player.Name] or 0) then
			return
		end

		local humanoid = entity.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.FloorMaterial == Enum.Material.Air then
			return
		end

		PlayerNextDashIframeAt[player.Name] = now + DASH_IFRAME_COOLDOWN
		entity:SetInvincibleFor(DASH_IFRAME_DURATION)
	end
end)

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
