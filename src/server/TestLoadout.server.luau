local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentServiceServer = require(ReplicatedStorage.Services.Equipment.EquipmentServiceServer)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local WeaponServiceServer = require(ReplicatedStorage.Services.Weapon.WeaponServiceServer)

local TEST_LOADOUT = {
	"Skeletal.Saber",
	"Damaged.Greatsword",
	"Skeletal.Lance",
	"Unbound.LastStrike",
}

local function ApplyTestLoadout(player: Player)
	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity.Character or entity.Character.Parent == nil then
		return
	end

	EquipmentServiceServer.ApplyLoadout(entity, TEST_LOADOUT)
	WeaponServiceServer.SyncEquippedWeapon(player)
end

local function BindPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			ApplyTestLoadout(player)
		end)
	end)

	if player.Character and player.Character.Parent ~= nil then
		task.defer(function()
			ApplyTestLoadout(player)
		end)
	end
end

Players.PlayerAdded:Connect(BindPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	BindPlayer(player)
end
