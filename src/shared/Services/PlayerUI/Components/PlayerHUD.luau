--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)
local EnemyServiceClient = require(ReplicatedStorage.Services.Enemy.EnemyServiceClient)
local PlayerServiceClient = require(ReplicatedStorage.Services.Player.PlayerServiceClient)
local StatusBarTemplate = require(script.Parent.StatusBarTemplate)

local HEALTH_LERP_SPEED = 4.5
local HEALTH_HIGH_COLOR = Color3.fromRGB(48, 176, 76)
local HEALTH_LOW_COLOR = Color3.fromRGB(198, 58, 58)
local HEALTH_LERP_COLOR = Color3.fromRGB(120, 22, 22)

local function formatStatLine(current: number, maximum: number, label: string): string
	return string.format("%d / %d %s", math.floor(current + 0.5), math.floor(maximum + 0.5), label)
end

local function getRatio(current: number, maximum: number): number
	if maximum <= 0 then
		return 0
	end

	return math.clamp(current / maximum, 0, 1)
end

local function getHealthColor(healthRatio: number): Color3
	return HEALTH_LOW_COLOR:Lerp(HEALTH_HIGH_COLOR, healthRatio)
end

local function readout(text: string, y: number)
	return React.createElement("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 22),
		Text = text,
		TextColor3 = Color3.fromRGB(0, 0, 0),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function separator(y: number)
	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 2),
	})
end

local function spawnButton()
	return React.createElement("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(120, 30),
		BackgroundColor3 = Color3.fromRGB(24, 24, 24),
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Text = "Spawn Enemy",
		TextColor3 = Color3.fromRGB(245, 245, 245),
		TextSize = 16,
		[React.Event.Activated] = function()
			EnemyServiceClient.RequestSpawnEnemy("Tests.Sword")
		end,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = Color3.fromRGB(0, 0, 0),
			Thickness = 1,
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
	})
end

local function PlayerHUD()
	local stats, setStats = React.useState(function()
		return PlayerServiceClient.GetStats()
	end)
	local healthDisplayRatio, setHealthDisplayRatio = React.useState(function()
		local initialStats = PlayerServiceClient.GetStats()
		return getRatio(initialStats.Health or 0, initialStats.MaxHealth or 0)
	end)

	React.useEffect(function()
		local connection = PlayerServiceClient.GetStatChangedSignal():Connect(function(statName: string, value: number)
			setStats(function(previousStats)
				local nextStats = table.clone(previousStats)
				nextStats[statName] = value
				return nextStats
			end)
		end)

		setStats(PlayerServiceClient.GetStats())

		return function()
			connection:Disconnect()
		end
	end, {})

	local health = stats.Health or 0
	local maxHealth = stats.MaxHealth or 0
	local mana = stats.Mana or 0
	local maxMana = stats.MaxMana or 0
	local healthRatio = getRatio(health, maxHealth)
	local manaRatio = getRatio(mana, maxMana)

	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
			setHealthDisplayRatio(function(previousRatio)
				local alpha = 1 - math.exp(-HEALTH_LERP_SPEED * deltaTime)
				local nextRatio = previousRatio + ((healthRatio - previousRatio) * alpha)
				if math.abs(nextRatio - healthRatio) <= 0.001 then
					return healthRatio
				end

				return nextRatio
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end, { healthRatio })

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -18),
		Size = UDim2.fromOffset(620, 106),
		BackgroundTransparency = 1,
	}, {
		HealthReadout = readout(formatStatLine(health, maxHealth, "HEALTH"), 0),
		HealthSeparator = separator(24),
		HealthBarPositioner = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.fromOffset(620, 20),
		}, {
			Bar = React.createElement(StatusBarTemplate, {
				Size = UDim2.fromOffset(620, 20),
				FillColor = HEALTH_LERP_COLOR,
				BackgroundTransparency = 0.02,
				FillRatio = healthDisplayRatio,
				OverlayFillColor = getHealthColor(healthRatio),
				OverlayFillRatio = healthRatio,
				OverlayTransparency = 0.02,
			}),
		}),
		ManaReadout = readout(formatStatLine(mana, maxMana, "MANA"), 56),
		ManaSeparator = separator(80),
		ManaBarPositioner = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 86),
			Size = UDim2.fromOffset(620, 20),
		}, {
			Bar = React.createElement(StatusBarTemplate, {
				Size = UDim2.fromOffset(620, 20),
				FillColor = Color3.fromRGB(34, 78, 168),
				BackgroundTransparency = 0.02,
				FillRatio = manaRatio,
			}),
		}),
		SpawnEnemyButton = spawnButton(),
	})
end

return PlayerHUD
