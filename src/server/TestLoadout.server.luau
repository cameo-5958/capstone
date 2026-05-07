local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentServiceServer = require(ReplicatedStorage.Services.Equipment.EquipmentServiceServer)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local WeaponServiceServer = require(ReplicatedStorage.Services.Weapon.WeaponServiceServer)

local DEFAULT_LOADOUT = {
	"Skeletal.Saber",
}

local function HasToolbarWeapons(entity): boolean
	for slot = 1, 4 do
		if entity:GetToolbarWeapon(slot) ~= nil then
			return true
		end
	end

	return false
end

local function ApplyDefaultLoadout(player: Player)
	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity.Character or entity.Character.Parent == nil then
		return
	end

	if HasToolbarWeapons(entity) then
		WeaponServiceServer.SyncEquippedWeapon(player)
		return
	end

	EquipmentServiceServer.ApplyLoadout(entity, DEFAULT_LOADOUT)
	WeaponServiceServer.SyncEquippedWeapon(player)
end

local function BindPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			ApplyDefaultLoadout(player)
		end)
	end)

	if player.Character and player.Character.Parent ~= nil then
		task.defer(function()
			ApplyDefaultLoadout(player)
		end)
	end
end

Players.PlayerAdded:Connect(BindPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	BindPlayer(player)
end
