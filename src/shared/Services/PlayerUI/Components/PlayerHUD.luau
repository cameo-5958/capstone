--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local StatusBarTemplate = require(script.Parent.StatusBarTemplate)

local function readout(text: string, y: number)
	return React.createElement("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 16),
		Text = text,
		TextColor3 = Color3.fromRGB(0, 0, 0),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function PlayerHUD()
	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 28, 1, -18),
		Size = UDim2.fromOffset(620, 82),
		BackgroundTransparency = 1,
	}, {
		HealthReadout = readout("100 / 100 HEALTH", 0),
		HealthBarPositioner = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.fromOffset(620, 20),
		}, {
			Bar = React.createElement(StatusBarTemplate, {
				Size = UDim2.fromOffset(620, 20),
				FillColor = Color3.fromRGB(172, 42, 42),
				BackgroundTransparency = 0.02,
			}),
		}),
		ManaBarPositioner = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.fromOffset(620, 20),
		}, {
			Bar = React.createElement(StatusBarTemplate, {
				Size = UDim2.fromOffset(620, 20),
				FillColor = Color3.fromRGB(34, 78, 168),
				BackgroundTransparency = 0.02,
			}),
		}),
		ManaReadout = readout("50 / 50 MANA", 66),
	})
end

return PlayerHUD
