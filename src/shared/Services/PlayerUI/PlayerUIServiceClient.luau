--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local PlayerHUD = require(script.Parent.Components.PlayerHUD)

local PlayerUIServiceClient = {}

local mountedRoot = nil
local mountedGui = nil

function PlayerUIServiceClient.init(): ()
	if mountedRoot then
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PlayerUI"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(React.createElement(PlayerHUD))

	mountedGui = screenGui
	mountedRoot = root
end

function PlayerUIServiceClient.destroy(): ()
	if mountedRoot then
		mountedRoot:unmount()
		mountedRoot = nil
	end

	if mountedGui then
		mountedGui:Destroy()
		mountedGui = nil
	end
end

return table.freeze(PlayerUIServiceClient)
