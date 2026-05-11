--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerUIServiceClient = require(ReplicatedStorage.Services.PlayerUI.PlayerUIServiceClient)
local _ProjectileServiceClient = require(ReplicatedStorage.Services.Projectile.ProjectileServiceClient)
local WorldServiceClient = require(ReplicatedStorage.Services.World.WorldServiceClient)

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_LIGHT_NAME = "PlayerVisionLight"

local function attachPlayerLight(character: Model)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local existing = rootPart:FindFirstChild(PLAYER_LIGHT_NAME)
	if existing and existing:IsA("PointLight") then
		existing.Enabled = true
		return
	end

	local light = Instance.new("PointLight")
	light.Name = PLAYER_LIGHT_NAME
	light.Brightness = 1.6
	light.Range = 20
	light.Shadows = false
	light.Color = Color3.fromRGB(255, 244, 220)
	light.Parent = rootPart
end

LOCAL_PLAYER.CharacterAdded:Connect(function(character)
	task.defer(attachPlayerLight, character)
end)
if LOCAL_PLAYER.Character then
	task.defer(attachPlayerLight, LOCAL_PLAYER.Character)
end

PlayerUIServiceClient.init()
WorldServiceClient.init()
