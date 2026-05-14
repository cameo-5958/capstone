--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local WorldServiceClient = require(ReplicatedStorage.Services.World.WorldServiceClient)

type Props = {
	IsLocked: boolean,
}

local PANEL_BG = Color3.fromRGB(38, 28, 19)
local PANEL_STROKE = Color3.fromRGB(156, 119, 67)
local TEXT_MAIN = Color3.fromRGB(245, 232, 205)
local TEXT_MUTED = Color3.fromRGB(205, 179, 138)
local READY_BG = Color3.fromRGB(86, 122, 70)
local UNREADY_BG = Color3.fromRGB(124, 78, 56)
local DISABLED_BG = Color3.fromRGB(67, 61, 52)

local function WardrobeReadyPanel(props: Props)
	local startState, setStartState = React.useState(function()
		return WorldServiceClient.GetStartState()
	end)

	React.useEffect(function()
		local connection = WorldServiceClient.GetStartStateChangedSignal():Connect(function(nextState)
			setStartState(nextState)
		end)

		setStartState(WorldServiceClient.GetStartState())

		return function()
			connection:Disconnect()
		end
	end, {})

	if startState.MatchStarted then
		return nil
	end

	local isReady = startState.LocalPlayerReady == true
	local readyCount = startState.ReadyCount or 0
	local totalPlayers = math.max(1, startState.TotalPlayers or 0)
	local statusText = if startState.WorldGenerating
		then "World generating in the background."
		elseif startState.WorldReady then "World ready. Waiting for everyone."
		else "Preparing the world."

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = PANEL_BG,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(360, 104),
		ZIndex = 30,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = PANEL_STROKE,
			Thickness = 1,
			Transparency = 0.12,
		}),
		Title = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -32, 0, 20),
			Text = string.format("Players ready: %d / %d", readyCount, totalPlayers),
			TextColor3 = TEXT_MAIN,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 31,
		}),
		Status = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Position = UDim2.fromOffset(16, 34),
			Size = UDim2.new(1, -32, 0, 18),
			Text = statusText,
			TextColor3 = TEXT_MUTED,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 31,
		}),
		Button = React.createElement("TextButton", {
			Active = true,
			AutoButtonColor = true,
			BackgroundColor3 = if props.IsLocked then READY_BG elseif isReady then UNREADY_BG else DISABLED_BG,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0, 16, 1, -46),
			Selectable = true,
			Size = UDim2.new(1, -32, 0, 32),
			Text = if isReady then "Unready" else "Ready",
			TextColor3 = TEXT_MAIN,
			TextSize = 14,
			ZIndex = 31,
			[React.Event.Activated] = function()
				WorldServiceClient.SetWardrobeReady(not isReady)
			end,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
		}),
		LockNote = if props.IsLocked
			then React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.new(0, 16, 1, -18),
				Size = UDim2.new(1, -32, 0, 14),
				Text = "Wardrobe locked while you are ready.",
				TextColor3 = TEXT_MUTED,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 31,
			})
			else nil,
	})
end

return WardrobeReadyPanel
