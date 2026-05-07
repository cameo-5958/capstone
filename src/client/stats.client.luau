--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)
local PlayerServiceClient = require(ReplicatedStorage.Services.Player.PlayerServiceClient)

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")
local GUI_NAME = "PlayerStatsHud"
local STAT_ORDER = {
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

local function FormatValue(value: number?): string
	return CombatNumbers.FormatTenth(value)
end

local existingGui = PLAYER_GUI:FindFirstChild(GUI_NAME)
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.Parent = PLAYER_GUI

local frame = Instance.new("Frame")
frame.Name = "StatsFrame"
frame.AnchorPoint = Vector2.new(0, 0)
frame.Position = UDim2.fromOffset(16, 16)
frame.Size = UDim2.fromOffset(240, 360)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 90, 110)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 24)
title.Font = Enum.Font.GothamBold
title.Text = "Player Stats"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local list = Instance.new("Frame")
list.Name = "StatList"
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(12, 40)
list.Size = UDim2.new(1, -24, 1, -52)
list.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local rows: { [string]: TextLabel } = {}

for index, statName in ipairs(STAT_ORDER) do
	local row = Instance.new("TextLabel")
	row.Name = statName
	row.BackgroundColor3 = Color3.fromRGB(36, 36, 48)
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 20)
	row.Font = Enum.Font.Code
	row.TextColor3 = Color3.fromRGB(230, 230, 235)
	row.TextSize = 14
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.LayoutOrder = index
	row.Parent = list

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 4)
	rowCorner.Parent = row

	rows[statName] = row
end

local function RenderStat(statName: string)
	local row = rows[statName]
	if not row then
		return
	end

	row.Text = string.format("%s: %s", statName, FormatValue(PlayerServiceClient.GetStat(statName)))
end

for _, statName in ipairs(STAT_ORDER) do
	RenderStat(statName)
end

PlayerServiceClient.GetStatChangedSignal():Connect(function(statName: string)
	RenderStat(statName)
end)
