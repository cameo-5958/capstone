--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local WorldServiceClient = require(ReplicatedStorage.Services.World.WorldServiceClient)
local WorldTypes = require(ReplicatedStorage.Services.World.WorldTypes)
local PlayerEndpoint = ReplicatedStorage:WaitForChild("Services"):WaitForChild("Player"):WaitForChild("PlayerEndpoint") :: RemoteEvent

type WorldRegenerateOptions = {
	Biome: string?,
	SpawnDebug: {
		EnemyBaseLevel: number?,
		GenerationType: string?,
	}?,
}

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")
local GUI_NAME = "WorldSpawnSandbox"
local TOGGLE_KEY = Enum.KeyCode.F6
local MIN_BASE_LEVEL = 1
local MAX_BASE_LEVEL = 120

local GENERATION_TYPES = {
	"Standard",
	"Boss",
	"Treasure",
	"NoPath",
}

local function gatherBiomeOptions(): { string }
	local options = {} :: { string }
	for biomeName in pairs(WorldTypes.BiomeMaterials) do
		table.insert(options, biomeName)
	end
	table.sort(options)
	return options
end

local BIOME_OPTIONS = gatherBiomeOptions()
if #BIOME_OPTIONS <= 0 then
	table.insert(BIOME_OPTIONS, "Plains")
end

local function findIndex(options: { string }, value: string?): number
	if type(value) ~= "string" then
		return 1
	end
	for index, option in ipairs(options) do
		if option == value then
			return index
		end
	end
	return 1
end

local function clampBaseLevel(value: number): number
	return math.clamp(math.floor(value + 0.5), MIN_BASE_LEVEL, MAX_BASE_LEVEL)
end

local existing = PLAYER_GUI:FindFirstChild(GUI_NAME)
if existing then
	existing:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 120
screenGui.Parent = PLAYER_GUI

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -20, 0, 20)
frame.Size = UDim2.fromOffset(340, 416)
frame.BackgroundColor3 = Color3.fromRGB(20, 25, 32)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = frame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(72, 88, 104)
frameStroke.Thickness = 1
frameStroke.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(14, 10)
title.Size = UDim2.new(1, -28, 0, 22)
title.Font = Enum.Font.GothamBold
title.Text = "Spawn Sandbox (Studio)"
title.TextColor3 = Color3.fromRGB(235, 242, 249)
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.BackgroundTransparency = 1
hint.Position = UDim2.fromOffset(14, 31)
hint.Size = UDim2.new(1, -28, 0, 16)
hint.Font = Enum.Font.Code
hint.Text = "Toggle panel: F6"
hint.TextColor3 = Color3.fromRGB(146, 165, 182)
hint.TextSize = 12
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(14, 56)
content.Size = UDim2.new(1, -28, 1, -70)
content.Parent = frame

local rowLayout = Instance.new("UIListLayout")
rowLayout.Padding = UDim.new(0, 8)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = content

local function createRow(labelText: string): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.Parent = content

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Size = UDim2.new(0, 150, 1, 0)
	label.Font = Enum.Font.Gotham
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(215, 226, 235)
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	return row
end

local function styleSelector(button: TextButton)
	button.BackgroundColor3 = Color3.fromRGB(33, 43, 56)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(240, 246, 252)
	button.TextSize = 14
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
end

local function styleTextBox(box: TextBox)
	box.BackgroundColor3 = Color3.fromRGB(33, 43, 56)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.Code
	box.TextColor3 = Color3.fromRGB(240, 246, 252)
	box.TextSize = 15
	box.ClearTextOnFocus = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = box
end

local currentConfig = WorldServiceClient.GetConfig()
local biomeIndex = findIndex(BIOME_OPTIONS, if currentConfig then currentConfig.Biome else nil)
local generationIndex = 1
local enemyBaseLevel = 20

local biomeRow = createRow("Biome")
local biomeButton = Instance.new("TextButton")
biomeButton.Name = "BiomeSelector"
biomeButton.AnchorPoint = Vector2.new(1, 0.5)
biomeButton.Position = UDim2.new(1, 0, 0.5, 0)
biomeButton.Size = UDim2.fromOffset(170, 30)
biomeButton.Text = BIOME_OPTIONS[biomeIndex]
biomeButton.Parent = biomeRow
styleSelector(biomeButton)

local generationRow = createRow("Generation Type")
local generationButton = Instance.new("TextButton")
generationButton.Name = "GenerationSelector"
generationButton.AnchorPoint = Vector2.new(1, 0.5)
generationButton.Position = UDim2.new(1, 0, 0.5, 0)
generationButton.Size = UDim2.fromOffset(170, 30)
generationButton.Text = GENERATION_TYPES[generationIndex]
generationButton.Parent = generationRow
styleSelector(generationButton)

local baseLevelRow = createRow("Enemy Base Level")
local baseLevelTextBox = Instance.new("TextBox")
baseLevelTextBox.Name = "EnemyBaseLevelInput"
baseLevelTextBox.AnchorPoint = Vector2.new(1, 0.5)
baseLevelTextBox.Position = UDim2.new(1, 0, 0.5, 0)
baseLevelTextBox.Size = UDim2.fromOffset(170, 30)
baseLevelTextBox.Text = tostring(enemyBaseLevel)
baseLevelTextBox.PlaceholderText = "1-120"
baseLevelTextBox.Parent = baseLevelRow
styleTextBox(baseLevelTextBox)

local buttonRow = Instance.new("Frame")
buttonRow.Name = "Buttons"
buttonRow.BackgroundTransparency = 1
buttonRow.Size = UDim2.new(1, 0, 0, 36)
buttonRow.Parent = content

local applyButton = Instance.new("TextButton")
applyButton.Name = "ApplyButton"
applyButton.BackgroundColor3 = Color3.fromRGB(55, 112, 71)
applyButton.BorderSizePixel = 0
applyButton.Position = UDim2.new(0, 0, 0, 0)
applyButton.Size = UDim2.new(0.5, -4, 1, 0)
applyButton.Font = Enum.Font.GothamBold
applyButton.Text = "Apply + Regenerate"
applyButton.TextColor3 = Color3.fromRGB(238, 248, 240)
applyButton.TextSize = 14
applyButton.Parent = buttonRow
local applyCorner = Instance.new("UICorner")
applyCorner.CornerRadius = UDim.new(0, 8)
applyCorner.Parent = applyButton

local resetModeButton = Instance.new("TextButton")
resetModeButton.Name = "ResetModeButton"
resetModeButton.BackgroundColor3 = Color3.fromRGB(55, 65, 79)
resetModeButton.BorderSizePixel = 0
resetModeButton.Position = UDim2.new(0.5, 4, 0, 0)
resetModeButton.Size = UDim2.new(0.5, -4, 1, 0)
resetModeButton.Font = Enum.Font.GothamBold
resetModeButton.Text = "Reset Mode"
resetModeButton.TextColor3 = Color3.fromRGB(229, 236, 244)
resetModeButton.TextSize = 14
resetModeButton.Parent = buttonRow
local resetCorner = Instance.new("UICorner")
resetCorner.CornerRadius = UDim.new(0, 8)
resetCorner.Parent = resetModeButton

local itemButtonRow = Instance.new("Frame")
itemButtonRow.Name = "ItemButtons"
itemButtonRow.BackgroundTransparency = 1
itemButtonRow.Size = UDim2.new(1, 0, 0, 36)
itemButtonRow.Parent = content

local grantWeaponsButton = Instance.new("TextButton")
grantWeaponsButton.Name = "GrantWeaponsButton"
grantWeaponsButton.BackgroundColor3 = Color3.fromRGB(64, 82, 112)
grantWeaponsButton.BorderSizePixel = 0
grantWeaponsButton.Position = UDim2.new(0, 0, 0, 0)
grantWeaponsButton.Size = UDim2.new(0.5, -4, 1, 0)
grantWeaponsButton.Font = Enum.Font.GothamBold
grantWeaponsButton.Text = "Grant All Weapons"
grantWeaponsButton.TextColor3 = Color3.fromRGB(228, 236, 248)
grantWeaponsButton.TextSize = 14
grantWeaponsButton.Parent = itemButtonRow
local grantWeaponsCorner = Instance.new("UICorner")
grantWeaponsCorner.CornerRadius = UDim.new(0, 8)
grantWeaponsCorner.Parent = grantWeaponsButton

local spawnItemsButton = Instance.new("TextButton")
spawnItemsButton.Name = "SpawnItemsButton"
spawnItemsButton.BackgroundColor3 = Color3.fromRGB(95, 83, 42)
spawnItemsButton.BorderSizePixel = 0
spawnItemsButton.Position = UDim2.new(0.5, 4, 0, 0)
spawnItemsButton.Size = UDim2.new(0.5, -4, 1, 0)
spawnItemsButton.Font = Enum.Font.GothamBold
spawnItemsButton.Text = "Grant All Database Items"
spawnItemsButton.TextColor3 = Color3.fromRGB(248, 238, 205)
spawnItemsButton.TextSize = 14
spawnItemsButton.Parent = itemButtonRow
local spawnItemsCorner = Instance.new("UICorner")
spawnItemsCorner.CornerRadius = UDim.new(0, 8)
spawnItemsCorner.Parent = spawnItemsButton

local damageRow = createRow("Take Damage")
local damageTextBox = Instance.new("TextBox")
damageTextBox.Name = "DamageInput"
damageTextBox.AnchorPoint = Vector2.new(1, 0.5)
damageTextBox.Position = UDim2.new(1, -88, 0.5, 0)
damageTextBox.Size = UDim2.fromOffset(82, 30)
damageTextBox.Text = "10"
damageTextBox.PlaceholderText = "Amount"
damageTextBox.Parent = damageRow
styleTextBox(damageTextBox)

local takeDamageButton = Instance.new("TextButton")
takeDamageButton.Name = "TakeDamageButton"
takeDamageButton.AnchorPoint = Vector2.new(1, 0.5)
takeDamageButton.Position = UDim2.new(1, 0, 0.5, 0)
takeDamageButton.Size = UDim2.fromOffset(78, 30)
takeDamageButton.BackgroundColor3 = Color3.fromRGB(120, 54, 54)
takeDamageButton.BorderSizePixel = 0
takeDamageButton.Font = Enum.Font.GothamBold
takeDamageButton.Text = "Damage"
takeDamageButton.TextColor3 = Color3.fromRGB(248, 232, 232)
takeDamageButton.TextSize = 13
takeDamageButton.Parent = damageRow
local takeDamageCorner = Instance.new("UICorner")
takeDamageCorner.CornerRadius = UDim.new(0, 8)
takeDamageCorner.Parent = takeDamageButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.BackgroundTransparency = 1
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Font = Enum.Font.Code
statusLabel.Text = "Ready"
statusLabel.TextColor3 = Color3.fromRGB(170, 189, 208)
statusLabel.TextSize = 13
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = content

local function readEnemyBaseLevel(): number
	local parsed = tonumber(baseLevelTextBox.Text)
	if type(parsed) ~= "number" then
		baseLevelTextBox.Text = tostring(enemyBaseLevel)
		return enemyBaseLevel
	end

	enemyBaseLevel = clampBaseLevel(parsed)
	baseLevelTextBox.Text = tostring(enemyBaseLevel)
	return enemyBaseLevel
end

local function cycleBiome()
	biomeIndex += 1
	if biomeIndex > #BIOME_OPTIONS then
		biomeIndex = 1
	end
	biomeButton.Text = BIOME_OPTIONS[biomeIndex]
end

local function cycleGenerationType()
	generationIndex += 1
	if generationIndex > #GENERATION_TYPES then
		generationIndex = 1
	end
	generationButton.Text = GENERATION_TYPES[generationIndex]
end

local function requestRegeneration()
	local level = readEnemyBaseLevel()
	local seedToUse = WorldServiceClient.GetSeed()
	local resolvedSeed = if seedToUse > 0 then seedToUse else nil
	local options: WorldRegenerateOptions = {
		Biome = BIOME_OPTIONS[biomeIndex],
		SpawnDebug = {
			EnemyBaseLevel = level,
			GenerationType = GENERATION_TYPES[generationIndex],
		},
	}
	statusLabel.Text = string.format(
		"Regenerating (%s, %s, L%d)...",
		options.Biome or "Unknown",
		options.SpawnDebug and options.SpawnDebug.GenerationType or "Standard",
		level
	)
	WorldServiceClient.RequestRegenerate(resolvedSeed, options)
end

local function readDamageAmount(): number
	local parsed = tonumber(damageTextBox.Text)
	if type(parsed) ~= "number" then
		damageTextBox.Text = "10"
		return 10
	end

	local clamped = math.max(1, math.floor(parsed + 0.5))
	damageTextBox.Text = tostring(clamped)
	return clamped
end

biomeButton.MouseButton1Click:Connect(cycleBiome)
generationButton.MouseButton1Click:Connect(cycleGenerationType)
baseLevelTextBox.FocusLost:Connect(function()
	readEnemyBaseLevel()
end)
applyButton.MouseButton1Click:Connect(requestRegeneration)
resetModeButton.MouseButton1Click:Connect(function()
	generationIndex = 1
	generationButton.Text = GENERATION_TYPES[generationIndex]
	statusLabel.Text = "Generation mode reset to Standard"
end)
grantWeaponsButton.MouseButton1Click:Connect(function()
	PlayerEndpoint:FireServer("DebugGrantAllWeapons", {})
	statusLabel.Text = "Granted all weapons"
end)
spawnItemsButton.MouseButton1Click:Connect(function()
	PlayerEndpoint:FireServer("DebugGrantAllNonConsumableItems", {})
	statusLabel.Text = "Granted all database items"
end)
takeDamageButton.MouseButton1Click:Connect(function()
	local amount = readDamageAmount()
	PlayerEndpoint:FireServer("DebugTakeDamage", {
		Amount = amount,
	})
	statusLabel.Text = string.format("Took %d damage", amount)
end)
damageTextBox.FocusLost:Connect(function()
	readDamageAmount()
end)

WorldServiceClient.GetWorldChangedSignal():Connect(function(action: string, payload: { [string]: any }?)
	if action ~= "InitializeWorld" then
		return
	end

	local seed = if payload and type(payload.Seed) == "number" then payload.Seed else WorldServiceClient.GetSeed()
	local config = payload and payload.Config
	if type(config) == "table" and type(config.Biome) == "string" then
		biomeIndex = findIndex(BIOME_OPTIONS, config.Biome)
		biomeButton.Text = BIOME_OPTIONS[biomeIndex]
	end
	statusLabel.Text = string.format("World ready (seed %d)", math.max(0, math.floor(seed)))
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == TOGGLE_KEY then
		frame.Visible = not frame.Visible
	end
end)
