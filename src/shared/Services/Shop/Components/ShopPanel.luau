--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local InventoryServiceClient = require(ReplicatedStorage.Services.Inventory.InventoryServiceClient)
local ShopServiceClient = require(ReplicatedStorage.Services.Shop.ShopServiceClient)

type ShopDisplayEntry = ShopServiceClient.ShopDisplayEntry
type ShopItemRequirement = ShopServiceClient.ShopItemRequirement
type ShopRecipe = ShopServiceClient.ShopRecipe
type ShopCatalog = ShopServiceClient.ShopCatalog

type Props = {
	Catalog: ShopCatalog,
	OnClose: (() -> ())?,
	TitleOverride: string?,
	SubtitleOverride: string?,
	Embedded: boolean?,
	PanelSize: UDim2?,
	MaxSize: Vector2?,
	MinSize: Vector2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

local PANEL_BG = Color3.fromRGB(24, 17, 11)
local PANEL_STROKE = Color3.fromRGB(167, 127, 67)
local HEADER_TEXT = Color3.fromRGB(248, 230, 193)
local BODY_TEXT = Color3.fromRGB(230, 214, 185)
local MUTED_TEXT = Color3.fromRGB(171, 150, 114)
local BUY_BG = Color3.fromRGB(120, 79, 34)
local BUY_BG_DISABLED = Color3.fromRGB(68, 56, 42)
local BUY_TEXT = Color3.fromRGB(255, 244, 221)
local ROW_BG = Color3.fromRGB(41, 29, 18)
local ROW_BG_ALT = Color3.fromRGB(34, 24, 15)
local AFFORDABLE = Color3.fromRGB(119, 201, 117)
local UNAFFORDABLE = Color3.fromRGB(213, 104, 95)
local COIN_COLOR = Color3.fromRGB(244, 214, 118)

local function formatDisplayEntry(entry: ShopDisplayEntry): string
	return string.format("%s x%d", entry.Name, math.max(1, entry.Quantity))
end

local function formatRequirement(requirement: ShopItemRequirement): string
	return string.format("%s x%d", requirement.Name, math.max(1, requirement.Quantity))
end

local function getRequirementQuantity(requirement: ShopItemRequirement): number
	return InventoryServiceClient.GetStackQuantity(requirement.ItemKind, requirement.StackKey, requirement.StorageSection)
end

local function recipeRow(recipe: ShopRecipe, rowIndex: number)
	local coins = InventoryServiceClient.GetCoins()
	local hasCoins = coins >= recipe.Coins
	local itemChildren = {}
	local hasItems = true

	for index, requirement in ipairs(recipe.Items) do
		local owned = getRequirementQuantity(requirement)
		if owned < requirement.Quantity then
			hasItems = false
		end

		itemChildren["Requirement_" .. index] = React.createElement("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			LayoutOrder = index,
			Size = UDim2.fromOffset(0, 0),
			Text = formatRequirement(requirement),
			TextColor3 = if owned >= requirement.Quantity then AFFORDABLE else UNAFFORDABLE,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local rewardTextParts = table.create(#recipe.Reward)
	for index, reward in ipairs(recipe.Reward) do
		rewardTextParts[index] = formatDisplayEntry(reward)
	end

	local isAffordable = hasCoins and hasItems
	local itemsChildren = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		}),
		None = if #recipe.Items == 0 then React.createElement("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, 0),
			Text = "No item trade-ins",
			TextColor3 = MUTED_TEXT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}) else nil,
	}
	for key, child in pairs(itemChildren) do
		itemsChildren[key] = child
	end

	return React.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = if rowIndex % 2 == 0 then ROW_BG_ALT else ROW_BG,
		BorderSizePixel = 0,
		LayoutOrder = rowIndex,
		Size = UDim2.new(1, 0, 0, 0),
	}, {
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if isAffordable then AFFORDABLE else PANEL_STROKE,
			Transparency = 0.5,
			Thickness = 1,
		}),
		Top = React.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
		}, {
			TradeText = React.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, -102, 0, 0),
				Text = string.format(
					"%s <- %s",
					table.concat(rewardTextParts, " + "),
					if recipe.Coins > 0 then string.format("Coins x%d", recipe.Coins) else "No coins"
				),
				TextColor3 = BODY_TEXT,
				TextSize = 16,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
			Buy = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				AutoButtonColor = true,
				BackgroundColor3 = if isAffordable then BUY_BG else BUY_BG_DISABLED,
				BorderSizePixel = 0,
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(90, 30),
				Text = recipe.ButtonText or "Buy",
				TextColor3 = BUY_TEXT,
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				Active = isAffordable,
				Selectable = isAffordable,
				[React.Event.Activated] = function()
					if isAffordable then
						ShopServiceClient.Purchase(recipe.Id)
					end
				end,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
			}),
		}),
		Items = React.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 36),
			Size = UDim2.new(1, 0, 0, 0),
		}, itemsChildren),
	})
end

local function ShopPanel(props: Props)
	local catalog, setCatalog = React.useState(function()
		return props.Catalog
	end)
	local inventoryVersion, setInventoryVersion = React.useState(0)
	local isEmbedded = props.Embedded == true
	local titleText = props.TitleOverride or catalog.Title
	local subtitleText = props.SubtitleOverride or "Reward <- coins item requirements"
	local panelSize = props.PanelSize or UDim2.new(0.88, 0, 0.72, 0)
	local panelMaxSize = props.MaxSize or Vector2.new(760, 420)
	local panelMinSize = props.MinSize or Vector2.new(340, 280)
	local panelPosition = props.Position or UDim2.fromScale(0.5, 0.5)
	local panelAnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)

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
		List = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, recipe in ipairs(catalog.Recipes) do
		recipeChildren["Recipe_" .. recipe.Id .. "_" .. tostring(inventoryVersion)] = recipeRow(recipe, index)
	end

	local panelChildren = {
		Panel = React.createElement("Frame", {
			AnchorPoint = panelAnchorPoint,
			BackgroundColor3 = PANEL_BG,
			BorderSizePixel = 0,
			Position = panelPosition,
			Size = panelSize,
		}, {
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = panelMaxSize,
				MinSize = panelMinSize,
			}),
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 14),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = PANEL_STROKE,
				Thickness = 1,
				Transparency = 0.08,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
				PaddingTop = UDim.new(0, 16),
			}),
			Title = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, if props.OnClose then -100 else 0, 0, 28),
				Text = titleText,
				TextColor3 = HEADER_TEXT,
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Subtitle = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.new(1, if props.OnClose then -100 else 0, 0, 18),
				Text = subtitleText,
				TextColor3 = MUTED_TEXT,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Close = if props.OnClose then React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = BUY_BG_DISABLED,
				BorderSizePixel = 0,
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(92, 32),
				Text = "Close",
				TextColor3 = BUY_TEXT,
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = props.OnClose,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
			}) else nil,
			List = React.createElement("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				Position = UDim2.fromOffset(0, 64),
				ScrollBarImageColor3 = PANEL_STROKE,
				ScrollBarThickness = 6,
				Size = UDim2.new(1, 0, 1, -64),
			}, recipeChildren),
		}),
	}

	if isEmbedded then
		return React.createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, panelChildren)
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, panelChildren)
end

return ShopPanel
