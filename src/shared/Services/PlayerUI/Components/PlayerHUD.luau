--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.react)
local BroadcastServiceClient = require(ReplicatedStorage.Services.PlayerUI.BroadcastServiceClient)
local PlayerServiceClient = require(ReplicatedStorage.Services.Player.PlayerServiceClient)
local ItemLoadoutServiceClient = require(ReplicatedStorage.Services.ItemLoadout.ItemLoadoutServiceClient)
local InventoryServiceClient = require(ReplicatedStorage.Services.Inventory.InventoryServiceClient)
local ShopServiceClient = require(ReplicatedStorage.Services.Shop.ShopServiceClient)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)
local StatusBarTemplate = require(script.Parent.StatusBarTemplate)
local ShopPanel = require(ReplicatedStorage.Services.Shop.Components.ShopPanel)
local WardrobeInventoryPanel = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeInventoryPanel)

local HEALTH_LERP_SPEED = 4.5
local HEALTH_HIGH_COLOR = Color3.fromRGB(48, 176, 76)
local HEALTH_LOW_COLOR = Color3.fromRGB(198, 58, 58)
local HEALTH_LERP_COLOR = Color3.fromRGB(120, 22, 22)
local MAIN_BROADCAST_COLOR = Color3.fromRGB(241, 226, 194)
local MAIN_BROADCAST_STROKE = Color3.fromRGB(74, 48, 31)
local ITEM_BROADCAST_COLOR = Color3.fromRGB(215, 234, 201)
local ITEM_BROADCAST_STROKE = Color3.fromRGB(45, 72, 40)
local ITEM_BAR_BG = Color3.fromRGB(31, 22, 14)
local ITEM_SLOT_BG = Color3.fromRGB(56, 38, 24)
local ITEM_SLOT_EMPTY_BG = Color3.fromRGB(40, 29, 20)
local ITEM_SLOT_STROKE = Color3.fromRGB(120, 86, 48)
local ITEM_TEXT = Color3.fromRGB(232, 221, 197)
local ITEM_MUTED_TEXT = Color3.fromRGB(162, 141, 112)
local ITEM_ACCENT = Color3.fromRGB(219, 177, 93)
local COIN_PANEL_BG = Color3.fromRGB(39, 29, 16)
local COIN_PANEL_STROKE = Color3.fromRGB(165, 124, 54)
local COIN_TEXT = Color3.fromRGB(247, 224, 149)
local COIN_VALUE = Color3.fromRGB(255, 242, 205)
local COIN_ICON = "rbxassetid://91090062173107"
local SHOP_BUTTON_BG = Color3.fromRGB(53, 40, 24)
local SHOP_BUTTON_STROKE = Color3.fromRGB(151, 112, 58)
local SHOP_BUTTON_TEXT = Color3.fromRGB(240, 224, 189)
local SLOT_PRESS_DURATION = 0.18
local SLOT_PRESS_SCALE_MIN = 0.9
local SLOT_PRESS_OFFSET = 3

type ItemLoadoutSlot = {
	Slot: number,
	EntryId: string?,
	ItemId: string?,
	Name: string?,
	Icon: string?,
	Quantity: number?,
	MaxStack: number?,
}

type ItemLoadoutSnapshot = {
	Slots: { ItemLoadoutSlot },
}

type WeaponHudData = {
	Name: string?,
	Icon: string?,
	HasAbility: boolean?,
	AbilityCooldown: number?,
}

type ShopDisplayEntry = ShopServiceClient.ShopDisplayEntry
type ShopItemRequirement = ShopServiceClient.ShopItemRequirement
type ShopRecipe = ShopServiceClient.ShopRecipe
type ShopCatalog = ShopServiceClient.ShopCatalog

type PressState = {
	Q: number,
	E: number,
	R: number,
}

local function getDefaultPressState(): PressState
	return {
		Q = -1,
		E = -1,
		R = -1,
	}
end

local function formatStatLine(current: number, maximum: number, label: string): string
	return ("%s / %s %s"):format(CombatNumbers.FormatTenth(current), CombatNumbers.FormatTenth(maximum), label)
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

local function getPressRatio(pressedAt: number, now: number): number
	if pressedAt < 0 then
		return 0
	end

	return math.clamp(1 - ((now - pressedAt) / SLOT_PRESS_DURATION), 0, 1)
end

local function createSlotAnimation(pressRatio: number): (number, number)
	local scale = 1 - ((1 - SLOT_PRESS_SCALE_MIN) * pressRatio)
	local offsetY = SLOT_PRESS_OFFSET * pressRatio
	return scale, offsetY
end

local function itemSlot(slot: ItemLoadoutSlot, keybind: string, layoutOrder: number, pressRatio: number)
	local isFilled = type(slot.EntryId) == "string" and slot.EntryId ~= ""
	local quantity = if type(slot.Quantity) == "number" then math.max(0, slot.Quantity) else 0
	local quantityText = if quantity > 0 then ("x%d"):format(quantity) else ""
	local slotScale, slotOffsetY = createSlotAnimation(pressRatio)

	return React.createElement("Frame", {
		BackgroundColor3 = if isFilled then ITEM_SLOT_BG else ITEM_SLOT_EMPTY_BG,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Position = UDim2.fromOffset(0, slotOffsetY),
		Size = UDim2.fromOffset(74, 74),
	}, {
		Scale = React.createElement("UIScale", {
			Scale = slotScale,
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if pressRatio > 0 then ITEM_ACCENT else ITEM_SLOT_STROKE,
			Thickness = if pressRatio > 0 then 2 else 1,
			Transparency = if isFilled then 0.1 else 0.35,
		}),
		Key = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(24, 16),
			Text = keybind,
			TextColor3 = ITEM_ACCENT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		IconFrame = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(26, 18, 12),
			BackgroundTransparency = if isFilled then 0.08 else 0.35,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0, 22),
			Size = UDim2.fromOffset(34, 34),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			Icon = if type(slot.Icon) == "string" and slot.Icon ~= "" then React.createElement("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = slot.Icon,
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(26, 26),
			}) else React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(24, 24),
				Text = if isFilled then "?" else "-",
				TextColor3 = if isFilled then ITEM_TEXT else ITEM_MUTED_TEXT,
				TextSize = 16,
			}),
		}),
		Quantity = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -6, 1, -6),
			Size = UDim2.fromOffset(42, 12),
			Text = quantityText,
			TextColor3 = ITEM_ACCENT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function abilitySlot(weapon: WeaponHudData?, pressRatio: number, cooldownRatio: number, cooldownText: string)
	local hasWeapon = weapon ~= nil
	local hasAbility = hasWeapon and weapon.HasAbility == true
	local weaponIcon = if hasWeapon and type(weapon.Icon) == "string" then weapon.Icon else nil
	local isCoolingDown = hasAbility and cooldownRatio > 0
	local statusText = if isCoolingDown then cooldownText else ""
	local slotScale, slotOffsetY = createSlotAnimation(pressRatio)

	return React.createElement("Frame", {
		BackgroundColor3 = if hasAbility then ITEM_SLOT_BG else ITEM_SLOT_EMPTY_BG,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Position = UDim2.fromOffset(0, slotOffsetY),
		Size = UDim2.fromOffset(74, 74),
	}, {
		Scale = React.createElement("UIScale", {
			Scale = slotScale,
		}),
		Corner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = React.createElement("UIStroke", {
			Color = if pressRatio > 0 then ITEM_ACCENT else ITEM_SLOT_STROKE,
			Thickness = if pressRatio > 0 then 2 else 1,
			Transparency = if hasAbility then 0.1 else 0.35,
		}),
		Key = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(24, 16),
			Text = "R",
			TextColor3 = ITEM_ACCENT,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		IconFrame = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(26, 18, 12),
			BackgroundTransparency = if hasAbility then 0.08 else 0.35,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 0, 22),
			Size = UDim2.fromOffset(34, 34),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			CooldownFill = if isCoolingDown then React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, cooldownRatio),
				ZIndex = 3,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
			}) else nil,
			Icon = if hasAbility and weaponIcon ~= nil and weaponIcon ~= "" then React.createElement("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = weaponIcon,
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(26, 26),
				ImageTransparency = if isCoolingDown then 1 else 0,
				ZIndex = 2,
			}) elseif hasAbility then React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(24, 24),
				Text = "R",
				TextColor3 = if isCoolingDown then Color3.fromRGB(24, 24, 24) else ITEM_TEXT,
				TextSize = 16,
				ZIndex = 4,
			}) else nil,
		}),
		Status = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(1, -6, 1, -6),
			Size = UDim2.fromOffset(42, 12),
			Text = statusText,
			TextColor3 = ITEM_ACCENT,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

local function PlayerHUD()
	local stats, setStats = React.useState(function()
		return PlayerServiceClient.GetStats()
	end)
	local broadcasts, setBroadcasts = React.useState(function()
		return BroadcastServiceClient.GetState()
	end)
	local itemLoadout, setItemLoadout = React.useState(function()
		return ItemLoadoutServiceClient.GetLoadoutData() :: ItemLoadoutSnapshot
	end)
	local equippedWeapon, setEquippedWeapon = React.useState(function()
		return WeaponServiceClient.GetEquippedWeaponData() :: WeaponHudData?
	end)
	local coins, setCoins = React.useState(function()
		return InventoryServiceClient.GetCoins()
	end)
	local shopCatalog, setShopCatalog = React.useState(function()
		return ShopServiceClient.GetCatalog() :: ShopCatalog
	end)
	local isItemInventoryOpen, setItemInventoryOpen = React.useState(false)
	local isShopOpen, setShopOpen = React.useState(false)
	local healthDisplayRatio, setHealthDisplayRatio = React.useState(function()
		local initialStats = PlayerServiceClient.GetStats()
		return getRatio(initialStats.Health or 0, initialStats.MaxHealth or 0)
	end)
	local uiNow, setUiNow = React.useState(os.clock())
	local pressedAt, setPressedAt = React.useState(getDefaultPressState)
	local abilityCooldownStartedAt, setAbilityCooldownStartedAt = React.useState(-1)
	local abilityCooldownStartedAtRef = React.useRef(-1)

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

	React.useEffect(function()
		local connection = InventoryServiceClient.GetInventoryChangedSignal():Connect(function()
			setCoins(InventoryServiceClient.GetCoins())
		end)

		InventoryServiceClient.RequestInventory()
		setCoins(InventoryServiceClient.GetCoins())

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local catalogConnection = ShopServiceClient.GetCatalogChangedSignal():Connect(function(nextCatalog: ShopCatalog)
			setShopCatalog(nextCatalog)
		end)
		local purchaseConnection = ShopServiceClient.GetPurchaseResultSignal():Connect(function(result: { [string]: any })
			if result.Success == true then
				BroadcastServiceClient.PushMainBroadcast("Purchase complete", 2.2)
			elseif result.Reason == "NotEnoughCoins" then
				BroadcastServiceClient.PushMainBroadcast("Not enough coins", 2.2)
			elseif result.Reason == "MissingItems" then
				BroadcastServiceClient.PushMainBroadcast("Missing required items", 2.2)
			else
				BroadcastServiceClient.PushMainBroadcast("Purchase failed", 2.2)
			end
		end)

		ShopServiceClient.RequestCatalog()
		setShopCatalog(ShopServiceClient.GetCatalog() :: ShopCatalog)

		return function()
			catalogConnection:Disconnect()
			purchaseConnection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		abilityCooldownStartedAtRef.current = abilityCooldownStartedAt
	end, { abilityCooldownStartedAt })

	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or UserInputService:GetFocusedTextBox() then
				return
			end

			local pressedKey: "Q" | "E" | "R"? = nil
			if input.KeyCode == Enum.KeyCode.Q then
				pressedKey = "Q"
			elseif input.KeyCode == Enum.KeyCode.E then
				pressedKey = "E"
			elseif input.KeyCode == Enum.KeyCode.R then
				pressedKey = "R"
			end

			if pressedKey ~= nil then
				local timestamp = os.clock()
				setPressedAt(function(previousState: PressState)
					local nextState = table.clone(previousState)
					if pressedKey == "Q" then
						nextState.Q = timestamp
					elseif pressedKey == "E" then
						nextState.E = timestamp
					else
						nextState.R = timestamp
					end
					return nextState
				end)

				if pressedKey == "R" then
					local currentWeapon = WeaponServiceClient.GetEquippedWeaponData() :: WeaponHudData?
					local abilityCooldown = if currentWeapon and type(currentWeapon.AbilityCooldown) == "number"
						then math.max(0, currentWeapon.AbilityCooldown)
						else 0
					local currentCooldownStartedAt = abilityCooldownStartedAtRef.current
					local elapsed = if currentCooldownStartedAt >= 0 then timestamp - currentCooldownStartedAt else math.huge
					local canRestartCooldown = abilityCooldown > 0 and elapsed >= abilityCooldown
					if abilityCooldown > 0 and (currentCooldownStartedAt < 0 or canRestartCooldown) then
						setAbilityCooldownStartedAt(timestamp)
					end
				end
			end

			if input.KeyCode == Enum.KeyCode.I then
				setItemInventoryOpen(function(previousValue)
					return not previousValue
				end)
			elseif input.KeyCode == Enum.KeyCode.B then
				setShopOpen(function(previousValue)
					return not previousValue
				end)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = BroadcastServiceClient.GetChangedSignal():Connect(function(nextState)
			setBroadcasts(nextState)
		end)

		setBroadcasts(BroadcastServiceClient.GetState())

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = ItemLoadoutServiceClient.GetLoadoutChangedSignal():Connect(function(nextLoadout: ItemLoadoutSnapshot)
			setItemLoadout(nextLoadout)
		end)

		ItemLoadoutServiceClient.RequestLoadout()
		setItemLoadout(ItemLoadoutServiceClient.GetLoadoutData() :: ItemLoadoutSnapshot)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = WeaponServiceClient.GetEquippedWeaponChangedSignal():Connect(function(nextWeapon)
			setEquippedWeapon(nextWeapon :: WeaponHudData?)
			setAbilityCooldownStartedAt(-1)
		end)

		WeaponServiceClient.RequestEquippedWeapon()
		setEquippedWeapon(WeaponServiceClient.GetEquippedWeaponData() :: WeaponHudData?)

		return function()
			connection:Disconnect()
		end
	end, {})

	local health = stats.Health or 0
	local maxHealth = stats.MaxHealth or 0
	local stamina = stats.Stamina or 0
	local maxStamina = stats.MaxStamina or 0
	local healthRatio = getRatio(health, maxHealth)
	local staminaRatio = getRatio(stamina, maxStamina)

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
			setUiNow(os.clock())
		end)

		return function()
			connection:Disconnect()
		end
	end, { healthRatio })

	local qPressRatio = getPressRatio(pressedAt.Q, uiNow)
	local ePressRatio = getPressRatio(pressedAt.E, uiNow)
	local rPressRatio = getPressRatio(pressedAt.R, uiNow)
	local abilityCooldownDuration = if equippedWeapon and type(equippedWeapon.AbilityCooldown) == "number"
		then math.max(0, equippedWeapon.AbilityCooldown)
		else 0
	local abilityCooldownElapsed = if abilityCooldownStartedAt >= 0 then uiNow - abilityCooldownStartedAt else math.huge
	local abilityCooldownRemaining = if abilityCooldownDuration > 0 and abilityCooldownStartedAt >= 0
		then math.max(0, abilityCooldownDuration - abilityCooldownElapsed)
		else 0
	local abilityCooldownRatio = if abilityCooldownDuration > 0
		then math.clamp(abilityCooldownRemaining / abilityCooldownDuration, 0, 1)
		else 0
	local abilityCooldownText = if abilityCooldownRemaining > 0
		then ("%ds"):format(math.ceil(abilityCooldownRemaining))
		else ""

	local itemBroadcastChildren = {}
	for index, entry in ipairs(broadcasts.ItemFeed) do
		itemBroadcastChildren["Item_" .. entry.Id] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Enum.Font.Code,
			Position = UDim2.new(1, 0, 0, (index - 1) * 28),
			Size = UDim2.fromOffset(0, 0),
			Text = entry.Text,
			TextColor3 = ITEM_BROADCAST_COLOR,
			TextSize = 18,
			TextStrokeColor3 = ITEM_BROADCAST_STROKE,
			TextStrokeTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 0),
				PaddingTop = UDim.new(0, 2),
			}),
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		MainBroadcast = if broadcasts.Main
			then React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromRGB(18, 12, 8),
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				Font = Enum.Font.Code,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.fromOffset(0, 0),
				Text = broadcasts.Main.Text,
				TextColor3 = MAIN_BROADCAST_COLOR,
				TextSize = 28,
				TextStrokeColor3 = MAIN_BROADCAST_STROKE,
				TextStrokeTransparency = 0,
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 18),
					PaddingRight = UDim.new(0, 18),
					PaddingTop = UDim.new(0, 10),
				}),
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
			})
			else nil,
		ItemBroadcastFeed = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -22, 0.46, 0),
			Size = UDim2.fromOffset(340, 140),
		}, itemBroadcastChildren),
		Coins = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = COIN_PANEL_BG,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -26, 0, 22),
			Size = UDim2.fromOffset(184, 44),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 10),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = COIN_PANEL_STROKE,
				Thickness = 1,
				Transparency = 0.1,
			}),
			Label = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.fromOffset(56, 14),
				Text = "Coins",
				TextColor3 = COIN_TEXT,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Icon = React.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = COIN_ICON,
				Position = UDim2.fromOffset(12, 18),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromOffset(16, 16),
			}),
			Value = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.Code,
				Position = UDim2.new(1, -12, 0.5, 2),
				Size = UDim2.fromOffset(104, 24),
				Text = tostring(coins),
				TextColor3 = COIN_VALUE,
				TextSize = 22,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
		ShopToggle = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = SHOP_BUTTON_BG,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -26, 0, 74),
			Size = UDim2.fromOffset(184, 36),
			Text = if isShopOpen then "B  Close Shop" else "B  Open Shop",
			TextColor3 = SHOP_BUTTON_TEXT,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			[React.Event.Activated] = function()
				setShopOpen(function(previousValue)
					return not previousValue
				end)
			end,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 10),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = SHOP_BUTTON_STROKE,
				Thickness = 1,
				Transparency = 0.12,
			}),
		}),
		BottomLeftHud = React.createElement("Frame", {
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
			StaminReadout = readout(formatStatLine(math.round(stamina), maxStamina, "STAMINA"), 56),
			StaminSeparator = separator(80),
			StaminBarPositioner = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 86),
				Size = UDim2.fromOffset(620, 20),
			}, {
				Bar = React.createElement(StatusBarTemplate, {
					Size = UDim2.fromOffset(620, 20),
					FillColor = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 0.02,
					FillRatio = staminaRatio,
				}),
			}),
		}),
		ItemHud = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = ITEM_BAR_BG,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -26, 1, -22),
			Size = UDim2.fromOffset(272, 84),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 12),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = ITEM_SLOT_STROKE,
				Thickness = 1,
				Transparency = 0.12,
			}),
			Slots = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(10, 5),
				Size = UDim2.new(1, -20, 1, -10),
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				SlotQ = itemSlot(itemLoadout.Slots[1] or { Slot = 1 }, "Q", 1, qPressRatio),
				SlotE = itemSlot(itemLoadout.Slots[2] or { Slot = 2 }, "E", 2, ePressRatio),
				Ability = abilitySlot(equippedWeapon, rPressRatio, abilityCooldownRatio, abilityCooldownText),
			}),
		}),
		ItemInventory = if isItemInventoryOpen
			then React.createElement(WardrobeInventoryPanel, {
				IsLocked = true,
				FilterMode = "ItemsOnly",
				TitleText = "Items",
			})
			else nil,
		Shop = if isShopOpen
			then React.createElement(ShopPanel, {
				Catalog = shopCatalog,
				OnClose = function()
					setShopOpen(false)
				end,
			})
			else nil,
	})
end

return PlayerHUD
