--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local NinePartBorder = require(ReplicatedStorage.Classes.UI.NinePartBorder)
local InventoryServiceClient = require(ReplicatedStorage.Services.Inventory.InventoryServiceClient)
local ShopServiceClient = require(ReplicatedStorage.Services.Shop.ShopServiceClient)

type ShopDisplayEntry = ShopServiceClient.ShopDisplayEntry
type ShopItemRequirement = ShopServiceClient.ShopItemRequirement
type ShopRecipe = ShopServiceClient.ShopRecipe
type ShopCatalog = ShopServiceClient.ShopCatalog

local PANEL_WIDTH = 500
local PANEL_HEIGHT = 420
local PANEL_LEFT_MARGIN = 24
local BORDER_THICKNESS = 24
local CONTENT_PAD = 20
local HEADER_HEIGHT = 38
local BODY_TOP = HEADER_HEIGHT + 18
local LIST_TOP = BODY_TOP + 28

local WOOD_DARK = Color3.fromRGB(28, 20, 9)
local WOOD_PANEL = Color3.fromRGB(34, 23, 10)
local WOOD_HEADER = Color3.fromRGB(72, 45, 19)
local GOLD = Color3.fromRGB(221, 156, 27)
local GOLD_DIM = Color3.fromRGB(110, 76, 23)
local TEXT_MAIN = Color3.fromRGB(245, 235, 212)
local TEXT_MUTED = Color3.fromRGB(178, 158, 132)
local ROW_BG = Color3.fromRGB(34, 54, 68)
local ROW_STROKE = Color3.fromRGB(77, 108, 130)
local AFFORDABLE = Color3.fromRGB(142, 231, 168)
local UNAFFORDABLE = Color3.fromRGB(217, 120, 110)
local BUY_BG = Color3.fromRGB(72, 45, 19)
local BUY_TEXT = Color3.fromRGB(241, 226, 194)
local TILE_BG = Color3.fromRGB(31, 44, 56)
local TILE_BG_COIN = Color3.fromRGB(70, 52, 22)
local TILE_STROKE = Color3.fromRGB(104, 138, 162)
local TILE_SIZE = 52

type Props = {
	Catalog: ShopCatalog,
}

local function label(text: string, position: UDim2, size: UDim2, props: { [string]: any }?)
	local resolvedProps = props or {}
	resolvedProps.BackgroundTransparency = resolvedProps.BackgroundTransparency or 1
	resolvedProps.BorderSizePixel = 0
	resolvedProps.Position = position
	resolvedProps.Size = size
	resolvedProps.Text = text
	resolvedProps.TextColor3 = resolvedProps.TextColor3 or TEXT_MAIN
	resolvedProps.TextSize = resolvedProps.TextSize or 14
	resolvedProps.Font = resolvedProps.Font or Enum.Font.Gotham
	resolvedProps.TextXAlignment = resolvedProps.TextXAlignment or Enum.TextXAlignment.Left
	resolvedProps.TextYAlignment = resolvedProps.TextYAlignment or Enum.TextYAlignment.Center
	resolvedProps.ZIndex = resolvedProps.ZIndex or 3
	return React.createElement("TextLabel", resolvedProps)
end

local function getRequirementQuantity(requirement: ShopItemRequirement): number
	return InventoryServiceClient.GetStackQuantity(requirement.ItemKind, requirement.StackKey, requirement.StorageSection)
end

local function squareTile(
	layoutOrder: number,
	title: string,
	quantity: number,
	color: Color3,
	strokeColor: Color3
)
	return React.createElement("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(TILE_SIZE, TILE_SIZE),
		ZIndex = 4,
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = 1,
			Transparency = 0.1,
		}),
		Name = label(title, UDim2.fromOffset(5, 6), UDim2.new(1, -10, 0, 26), {
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 5,
		}),
		Quantity = label("x" .. tostring(math.max(1, quantity)), UDim2.fromOffset(0, TILE_SIZE - 18), UDim2.new(1, 0, 0, 12), {
			Font = Enum.Font.Code,
			TextSize = 12,
			TextColor3 = TEXT_MAIN,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5,
		}),
	})
end

local function plusSeparator(layoutOrder: number)
	return label("+", UDim2.fromOffset(0, 0), UDim2.fromOffset(14, TILE_SIZE), {
		LayoutOrder = layoutOrder,
		Font = Enum.Font.GothamBlack,
		TextColor3 = GOLD,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

local function arrowTile(layoutOrder: number)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(34, TILE_SIZE),
		ZIndex = 4,
	}, {
		Shaft = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, math.floor(TILE_SIZE * 0.5)),
			Size = UDim2.fromOffset(18, 4),
			ZIndex = 5,
		}),
		HeadTop = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(19, math.floor(TILE_SIZE * 0.5) - 6),
			Rotation = 35,
			Size = UDim2.fromOffset(12, 4),
			ZIndex = 5,
		}),
		HeadBottom = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(19, math.floor(TILE_SIZE * 0.5) + 6),
			Rotation = -35,
			Size = UDim2.fromOffset(12, 4),
			ZIndex = 5,
		}),
	})
end

local function recipeCard(recipe: ShopRecipe, rowIndex: number)
	local coins = InventoryServiceClient.GetCoins()
	local hasCoins = coins >= recipe.Coins
	local hasItems = true
	local costChildren = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
	}
	local reward = recipe.Reward[1]
	local nextOrder = 1

	costChildren.Reward = squareTile(nextOrder, if reward then reward.Name else "Reward", if reward then reward.Quantity else 1, TILE_BG, TILE_STROKE)
	nextOrder += 1
	costChildren.Arrow = arrowTile(nextOrder)
	nextOrder += 1
	costChildren.Coins = squareTile(nextOrder, "Coins", math.max(0, recipe.Coins), TILE_BG_COIN, if hasCoins then AFFORDABLE else UNAFFORDABLE)
	nextOrder += 1

	for index, requirement in ipairs(recipe.Items) do
		local owned = getRequirementQuantity(requirement)
		if owned < requirement.Quantity then
			hasItems = false
		end

		costChildren["Plus_" .. index] = plusSeparator(nextOrder)
		nextOrder += 1
		costChildren["Requirement_" .. index] = squareTile(
			nextOrder,
			requirement.Name,
			requirement.Quantity,
			TILE_BG,
			if owned >= requirement.Quantity then AFFORDABLE else UNAFFORDABLE
		)
		nextOrder += 1
	end

	local isAffordable = hasCoins and hasItems

	return React.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = ROW_BG,
		BackgroundTransparency = if rowIndex % 2 == 0 then 0.08 else 0.02,
		BorderSizePixel = 0,
		LayoutOrder = rowIndex,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 3,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = if isAffordable then AFFORDABLE else ROW_STROKE,
			Thickness = 1,
			Transparency = 0.18,
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
		}),
		Buy = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Active = isAffordable,
			AutoButtonColor = isAffordable,
			BackgroundColor3 = if isAffordable then BUY_BG else Color3.fromRGB(55, 48, 39),
			BorderSizePixel = 0,
			Position = UDim2.new(1, 0, 0, 0),
			Selectable = isAffordable,
			Size = UDim2.fromOffset(84, 28),
			Text = recipe.ButtonText or "Craft",
			TextColor3 = BUY_TEXT,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			ZIndex = 4,
			[React.Event.Activated] = function()
				if isAffordable then
					ShopServiceClient.Purchase(recipe.Id)
				end
			end,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = if isAffordable then GOLD else GOLD_DIM,
				Thickness = 1,
				Transparency = 0.22,
			}),
		}),
		Trade = React.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(1, -96, 0, 0),
			ZIndex = 3,
		}, costChildren),
	})
end

local function WardrobeCraftingPanel(props: Props)
	local catalog, setCatalog = React.useState(function()
		return props.Catalog
	end)
	local inventoryVersion, setInventoryVersion = React.useState(0)

	React.useEffect(function()
		setCatalog(props.Catalog)
	end, { props.Catalog })

	React.useEffect(function()
		local inventoryConnection = InventoryServiceClient.GetInventoryChangedSignal():Connect(function()
			setInventoryVersion(function(previousValue)
				return previousValue + 1
			end)
		end)
		local catalogConnection = ShopServiceClient.GetCatalogChangedSignal():Connect(function(nextCatalog: ShopCatalog)
			setCatalog(nextCatalog)
		end)

		InventoryServiceClient.RequestInventory()
		ShopServiceClient.RequestCatalog()

		return function()
			inventoryConnection:Disconnect()
			catalogConnection:Disconnect()
		end
	end, {})

	local recipeChildren = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, recipe in ipairs(catalog.Recipes) do
		recipeChildren["Recipe_" .. recipe.Id .. "_" .. tostring(inventoryVersion)] = recipeCard(recipe, index)
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, PANEL_LEFT_MARGIN, 0.5, 0),
		Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
	}, {
		Fill = React.createElement("Frame", {
			BackgroundColor3 = WOOD_DARK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(5, 5),
			Size = UDim2.new(1, -10, 1, -10),
			ZIndex = 1,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = GOLD,
				Thickness = 1,
				Transparency = 0.08,
			}),
			BodyShade = React.createElement("Frame", {
				BackgroundColor3 = WOOD_PANEL,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(6, HEADER_HEIGHT + 7),
				Size = UDim2.new(1, -12, 1, -(HEADER_HEIGHT + 13)),
				ZIndex = 1,
			}),
		}),
		Border = React.createElement(NinePartBorder.Component, {
			Thickness = BORDER_THICKNESS,
			UseQuirkyBottomRight = false,
			ZIndex = 10,
		}),
		Header = React.createElement("Frame", {
			BackgroundColor3 = WOOD_HEADER,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, HEADER_HEIGHT),
			ZIndex = 2,
		}, {
			Title = label("Crafting", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), {
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(232, 188, 82),
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			BottomLine = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = GOLD_DIM,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 1),
				ZIndex = 3,
			}),
		}),
		Subtitle = label("Crafted item <- coins item requirements", UDim2.fromOffset(CONTENT_PAD, BODY_TOP), UDim2.new(1, -(CONTENT_PAD * 2), 0, 18), {
			TextColor3 = TEXT_MUTED,
			TextSize = 10,
			Font = Enum.Font.GothamBold,
		}),
		List = React.createElement("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			Position = UDim2.fromOffset(CONTENT_PAD, LIST_TOP),
			ScrollBarImageColor3 = GOLD_DIM,
			ScrollBarThickness = 5,
			Size = UDim2.new(1, -(CONTENT_PAD * 2), 1, -(LIST_TOP + CONTENT_PAD)),
			ZIndex = 3,
		}, recipeChildren),
	})
end

return WardrobeCraftingPanel
