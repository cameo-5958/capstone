--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local NinePartBorder = require(ReplicatedStorage.Classes.UI.NinePartBorder)
local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)
local InventoryServiceClient = require(ReplicatedStorage.Services.Inventory.InventoryServiceClient)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local WardrobePreviewLoader = require(ReplicatedStorage.Viewports.Wardrobe.WardrobePreviewLoader)
local WardrobeSelection = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeSelection)

type SelectedItem = WardrobeSelection.SelectedItem

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")
local InventoryItemsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("InventoryItems")

type InventoryEntry = {
	EntryId: string,
	ItemKind: string,
	StorageSection: string,
	StackKey: string,
	Quantity: number,
	MaxStack: number,
	Data: { [string]: any },
}

type InventorySnapshot = {
	Entries: { [string]: InventoryEntry },
}

type LoadoutSlot = {
	Slot: number,
	IsEquipped: boolean?,
	ItemKind: string?,
	Name: string?,
	Class: string?,
	Type: string?,
	InstanceId: string?,
	WeaponId: string?,
	BaseDamage: number?,
	GrantedStats: { [string]: number }?,
}

type LoadoutSnapshot = {
	EquippedIndex: number?,
	Slots: { LoadoutSlot },
}

type HotbarInfo = {
	Slot: number,
	IsEquipped: boolean,
}

type HotbarInfoLookup = {
	ByInstanceId: { [string]: HotbarInfo },
	ByWeaponId: { [string]: { HotbarInfo } },
}

type InventoryCategory = "Items" | "Consumables" | "Armor" | "Weapons"
type InventoryFilterMode = "Full" | "ItemsOnly"

local PANEL_WIDTH = 320
local PANEL_HEIGHT = 430
local PANEL_RIGHT_MARGIN = 64
local TILE_PADDING = 8
local GRID_INSET = 4
local GRID_COLUMNS = 3
local MIN_GRID_ROWS = 4
local PANEL_BORDER_SCALE = 0.86
local PANEL_BORDER_THICKNESS = math.floor(NinePartBorder.RenderedPartSize * PANEL_BORDER_SCALE)
local PANEL_INNER_INSET = NinePartBorder.GetInnerInset(PANEL_BORDER_THICKNESS)
local PANEL_CONTENT_WIDTH = PANEL_WIDTH - (PANEL_INNER_INSET * 2)
local PANEL_CONTENT_HEIGHT = PANEL_HEIGHT - (PANEL_INNER_INSET * 2)
local GRID_SCROLLBAR_GUTTER = 4
local CATEGORY_TILE_GAP = 6
local TILE_SIZE = math.floor(
	(PANEL_CONTENT_WIDTH - (GRID_INSET * 2) - GRID_SCROLLBAR_GUTTER - ((GRID_COLUMNS - 1) * TILE_PADDING))
		/ GRID_COLUMNS
)
local TITLE_SIGN_IMAGE = "rbxassetid://75446135539310"
local TITLE_SIGN_SOURCE_SIZE = Vector2.new(368, 156)
local TITLE_SIGN_CENTER_FROM_BOTTOM = 70
local TITLE_SIGN_WIDTH = math.floor(PANEL_CONTENT_WIDTH * 0.88 * 0.68)
local TITLE_SIGN_HEIGHT = math.floor(TITLE_SIGN_WIDTH * (TITLE_SIGN_SOURCE_SIZE.Y / TITLE_SIGN_SOURCE_SIZE.X))
local TITLE_SIGN_TOP_Y = PANEL_INNER_INSET
local TITLE_SIGN_TEXT_CENTER_Y = (TITLE_SIGN_SOURCE_SIZE.Y - TITLE_SIGN_CENTER_FROM_BOTTOM) / TITLE_SIGN_SOURCE_SIZE.Y
local TITLE_SIGN_TEXT_HEIGHT = math.floor(TITLE_SIGN_HEIGHT * 0.42)
local LIST_TOP = math.floor(math.max(58, TITLE_SIGN_TOP_Y + TITLE_SIGN_HEIGHT + 8 - PANEL_INNER_INSET))

local FOREST_PANEL_BACKGROUND = Color3.fromRGB(54, 35, 23)
local FOREST_PANEL_STROKE = Color3.fromRGB(126, 84, 48)
local FOREST_TILE_BACKGROUND = Color3.fromRGB(70, 45, 28)
local FOREST_TILE_BACKGROUND_ALT = Color3.fromRGB(82, 53, 32)
local FOREST_LABEL_BACKGROUND = Color3.fromRGB(34, 21, 13)
local FOREST_TEXT = Color3.fromRGB(239, 222, 190)
local FOREST_MUTED_TEXT = Color3.fromRGB(196, 162, 118)
local FOREST_ACCENT = Color3.fromRGB(223, 173, 91)
local FOREST_HOTBAR = Color3.fromRGB(170, 109, 54)
local FOREST_SHADOW = Color3.fromRGB(14, 8, 4)
local RARITY_BACKGROUNDS = {
	CRUDE = Color3.fromRGB(82, 84, 84),
	REFINED = Color3.fromRGB(58, 88, 110),
	EXALTED = Color3.fromRGB(136, 95, 43),
	APEX = Color3.fromRGB(126, 28, 32),
}

local function normalizeRarity(rarity: any): string
	if type(rarity) ~= "string" or rarity == "" then
		return "CRUDE"
	end

	local normalized = string.upper(rarity)
	if normalized == "COMMON" then
		return "CRUDE"
	end

	if RARITY_BACKGROUNDS[normalized] then
		return normalized
	end

	return "CRUDE"
end

local function getEntryName(entry: InventoryEntry): string
	local data = entry.Data
	local name = data.Name or data.DisplayName
	if type(name) == "string" and name ~= "" then
		return name
	end

	local itemId = data.ItemId
	if type(itemId) == "string" and itemId ~= "" then
		return itemId
	end

	local weaponId = data.WeaponId
	if type(weaponId) == "string" and weaponId ~= "" then
		return weaponId
	end

	return entry.ItemKind
end

local function getEntryDetail(entry: InventoryEntry): string
	local data = entry.Data
	if entry.ItemKind == "Weapon" then
		local weaponClass = if type(data.Class) == "string" then data.Class else "Weapon"
		local baseDamage = if type(data.BaseDamage) == "number" then data.BaseDamage else 0
		return ("%s  DMG %s"):format(weaponClass, CombatNumbers.FormatTenth(baseDamage))
	end

	if entry.ItemKind == "Consumable" or entry.ItemKind == "Item" then
		local category = if type(data.InventoryData) == "table"
				and type(data.InventoryData.Category) == "string"
			then data.InventoryData.Category
			else "Consumable"
		return ("%s  Stack %d"):format(category, entry.Quantity)
	end

	if entry.ItemKind == "InventoryItem" then
		local category = if type(data.InventoryData) == "table"
				and type(data.InventoryData.Category) == "string"
			then data.InventoryData.Category
			else "Item"
		return ("%s  Stack %d"):format(category, entry.Quantity)
	end

	return ("Stack %d / %d"):format(entry.Quantity, entry.MaxStack)
end

local function getEntryWeaponId(entry: InventoryEntry): string?
	local weaponId = entry.Data.WeaponId
	if type(weaponId) == "string" and weaponId ~= "" then
		return weaponId
	end

	return nil
end

local function getEntryInstanceId(entry: InventoryEntry): string?
	local instanceId = entry.Data.InstanceId
	if type(instanceId) == "string" and instanceId ~= "" then
		return instanceId
	end

	return nil
end

local function getEntryRarity(entry: InventoryEntry): string
	return normalizeRarity(entry.Data.Rarity)
end

local function getEntryIcon(entry: InventoryEntry): string?
	local data = entry.Data
	local icon = data.Icon or data.IconImage or data.Image
	if type(icon) == "string" and icon ~= "" then
		return icon
	end
	return nil
end

local function getEntryCategory(entry: InventoryEntry): InventoryCategory
	if entry.ItemKind == "Weapon" then
		return "Weapons"
	end

	if entry.ItemKind == "Armor" then
		return "Armor"
	end

	if entry.ItemKind == "InventoryItem" then
		return "Items"
	end

	local data = entry.Data
	local inventoryData = data.InventoryData
	local inventoryType = if type(inventoryData) == "table" and type(inventoryData.Type) == "string"
		then string.lower(inventoryData.Type)
		else ""
	local itemType = if type(data.Type) == "string" then string.lower(data.Type) else ""

	if inventoryType == "armor" or itemType == "armor" then
		return "Armor"
	end

	return "Consumables"
end

local function cloneEntryData(entry: InventoryEntry): { [string]: any }
	local clone = {}
	for key, value in pairs(entry.Data) do
		clone[key] = value
	end
	return clone
end

local function getLoadoutHotbarLookup(loadout: LoadoutSnapshot): HotbarInfoLookup
	local lookup = {
		ByInstanceId = {},
		ByWeaponId = {},
	}

	for index = 1, 4 do
		local slot = loadout.Slots[index]
		local instanceId = slot and slot.InstanceId
		local weaponId = slot and slot.WeaponId
		if (type(instanceId) == "string" and instanceId ~= "") or (type(weaponId) == "string" and weaponId ~= "") then
			local slotNumber = slot.Slot or index
			local hotbarInfo = {
				Slot = slotNumber,
				IsEquipped = slot.IsEquipped == true or loadout.EquippedIndex == slotNumber,
			}
			if type(instanceId) == "string" and instanceId ~= "" then
				lookup.ByInstanceId[instanceId] = hotbarInfo
			end
			if type(weaponId) == "string" and weaponId ~= "" then
				local weaponMatches = lookup.ByWeaponId[weaponId]
				if not weaponMatches then
					weaponMatches = {}
					lookup.ByWeaponId[weaponId] = weaponMatches
				end
				table.insert(weaponMatches, hotbarInfo)
			end
		end
	end

	return lookup
end

local function getHotbarInfoByEntryId(entries: { InventoryEntry }, loadout: LoadoutSnapshot): { [string]: HotbarInfo }
	local lookup = getLoadoutHotbarLookup(loadout)
	local infoByEntryId = {}
	local matchedSlots = {}

	for _, entry in ipairs(entries) do
		local instanceId = getEntryInstanceId(entry)
		local hotbarInfo = instanceId and lookup.ByInstanceId[instanceId] or nil
		if hotbarInfo then
			infoByEntryId[entry.EntryId] = hotbarInfo
			matchedSlots[hotbarInfo.Slot] = true
		end
	end

	for _, entry in ipairs(entries) do
		if infoByEntryId[entry.EntryId] then
			continue
		end

		local weaponId = getEntryWeaponId(entry)
		local weaponMatches = weaponId and lookup.ByWeaponId[weaponId] or nil
		if not weaponMatches then
			continue
		end

		for _, hotbarInfo in ipairs(weaponMatches) do
			if not matchedSlots[hotbarInfo.Slot] then
				infoByEntryId[entry.EntryId] = hotbarInfo
				matchedSlots[hotbarInfo.Slot] = true
				break
			end
		end
	end

	return infoByEntryId
end

local function buildSelectedInventoryItem(entry: InventoryEntry, hotbarInfo: HotbarInfo?): SelectedItem
	local data = entry.Data
	local selectedId = if type(data.WeaponId) == "string"
		then data.WeaponId
		elseif type(data.ItemId) == "string" then data.ItemId
		else entry.StackKey
	local name = if type(data.Name) == "string" then data.Name else getEntryName(entry)
	local class = if type(data.Class) == "string" then data.Class else nil
	local itemType = if type(data.Type) == "string"
		then data.Type
		elseif
			type(data.InventoryData) == "table" and type(data.InventoryData.Type) == "string"
		then data.InventoryData.Type
		else nil

	return {
		ItemKind = entry.ItemKind,
		Source = "Inventory",
		EntryId = entry.EntryId,
		Slot = nil,
		HotbarSlot = hotbarInfo and hotbarInfo.Slot or nil,
		IsHotbar = hotbarInfo ~= nil,
		IsEquipped = hotbarInfo ~= nil and hotbarInfo.IsEquipped or false,
		Name = name,
		Id = selectedId,
		Class = class,
		Type = itemType,
		Quantity = entry.Quantity,
		MaxStack = entry.MaxStack,
		Data = cloneEntryData(entry),
	}
end

local function resolveWeaponModelTemplate(entry: InventoryEntry): Instance?
	if entry.ItemKind ~= "Weapon" then
		return nil
	end

	local weaponId = entry.Data.WeaponId
	if type(weaponId) ~= "string" or weaponId == "" then
		return nil
	end

	local current: Instance = WeaponsDatabase
	for _, part in ipairs(weaponId:split(".")) do
		local child = current:FindFirstChild(part)
		if not child then
			return nil
		end

		current = child
	end

	local namedModel = current:FindFirstChild("Model")
	if namedModel then
		return namedModel
	end

	for _, child in ipairs(current:GetChildren()) do
		if
			child.Name ~= "Data"
			and (child:IsA("Tool") or child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder"))
		then
			return child
		end
	end

	return nil
end

local function buildInventoryItemModel(entry: InventoryEntry): Model?
	if entry.ItemKind ~= "InventoryItem" then
		return nil
	end

	local itemId = entry.Data.ItemId
	if type(itemId) ~= "string" or itemId == "" then
		return nil
	end

	local folder = InventoryItemsDatabase:FindFirstChild(itemId)
	if not folder or not folder:IsA("Folder") then
		return nil
	end

	local namedModel = folder:FindFirstChild("Model")
	if namedModel and namedModel:IsA("Model") then
		return namedModel:Clone()
	end

	local modelBuilder = folder:FindFirstChild("ModelBuilder")
	if modelBuilder and modelBuilder:IsA("ModuleScript") then
		local ok, exported = pcall(require, modelBuilder)
		if not ok then
			return nil
		end

		local builderFn: (() -> Model)? = nil
		if type(exported) == "function" then
			builderFn = exported
		elseif type(exported) == "table" and type((exported :: any).Build) == "function" then
			builderFn = function()
				return (exported :: any).Build()
			end
		end

		if builderFn then
			local built = builderFn()
			if built and built:IsA("Model") then
				return built
			end
		end
	end

	return nil
end

local function prepVisualClone(instance: Instance): ()
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

local function cloneEntryVisual(entry: InventoryEntry): Model?
	local clone: Instance? = nil
	if entry.ItemKind == "Weapon" then
		local template = resolveWeaponModelTemplate(entry)
		if template then
			clone = template:Clone()
		end
	elseif entry.ItemKind == "InventoryItem" then
		clone = buildInventoryItemModel(entry)
	end

	if not clone then
		return nil
	end
	prepVisualClone(clone)

	if clone:IsA("Model") then
		return clone
	end

	local previewModel = Instance.new("Model")
	previewModel.Name = "InventoryItemPreview"

	if clone:IsA("Tool") or clone:IsA("Folder") then
		for _, child in ipairs(clone:GetChildren()) do
			if child:IsA("BasePart") or child:IsA("Model") then
				child.Parent = previewModel
			else
				child:Destroy()
			end
		end
		clone:Destroy()
	elseif clone:IsA("BasePart") then
		clone.Parent = previewModel
	else
		clone:Destroy()
		previewModel:Destroy()
		return nil
	end

	return previewModel
end

local function frameWeaponModel(camera: Camera, model: Model): ()
	model:PivotTo(CFrame.Angles(0, math.rad(-35), math.rad(-12)))

	local boundingCFrame, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z, 1) * 0.5
	local focus = boundingCFrame.Position
	local fieldOfView = 34
	local distance = (radius / math.tan(math.rad(fieldOfView) * 0.5)) * 1.45
	local cameraPosition = focus + Vector3.new(radius * 0.7, radius * 0.18, distance)

	camera.CFrame = CFrame.lookAt(cameraPosition, focus)
	camera.FieldOfView = fieldOfView
end

local function InventoryItemViewport(props: { Entry: InventoryEntry })
	local viewportRef = React.useRef(nil :: ViewportFrame?)
	local entry = props.Entry
	local weaponId = if type(entry.Data.WeaponId) == "string" then entry.Data.WeaponId else ""

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return nil
		end
		local disposed = false

		for _, child in ipairs(viewport:GetChildren()) do
			child:Destroy()
		end

		local worldModel = Instance.new("WorldModel")
		worldModel.Name = "WorldModel"
		worldModel.Parent = viewport

		local camera = Instance.new("Camera")
		camera.Name = "ItemCamera"
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		local previewModel = cloneEntryVisual(entry)
		if previewModel then
			task.spawn(function()
				WardrobePreviewLoader.PreloadInstanceAssets(previewModel)

				if disposed or viewportRef.current ~= viewport then
					previewModel:Destroy()
					return
				end

				previewModel.Parent = worldModel
				frameWeaponModel(camera, previewModel)
			end)
		end

		return function()
			disposed = true
			if previewModel and previewModel.Parent == nil then
				previewModel:Destroy()
			end

			viewport.CurrentCamera = nil
			worldModel:Destroy()
			camera:Destroy()
		end
	end, { entry.EntryId, entry.ItemKind, weaponId, entry.Data.ItemId })

	return React.createElement("ViewportFrame", {
		ref = viewportRef,
		Ambient = Color3.fromRGB(180, 190, 205),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LightColor = Color3.fromRGB(255, 248, 232),
		LightDirection = Vector3.new(-0.35, -0.7, -0.45),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	})
end

local function inventoryTile(
	entry: InventoryEntry,
	index: number,
	isSelected: boolean,
	hotbarInfo: HotbarInfo?,
	onSelected: () -> (),
	isInteractive: boolean
)
	local quantityText = if entry.Quantity > 1 then "x" .. tostring(entry.Quantity) else ""
	local rarity = getEntryRarity(entry)
	local icon = getEntryIcon(entry)
	local tileBackground = RARITY_BACKGROUNDS[rarity] or FOREST_TILE_BACKGROUND
	local strokeColor = if isSelected then FOREST_ACCENT elseif hotbarInfo then FOREST_HOTBAR else FOREST_PANEL_STROKE
	local strokeTransparency = if isSelected then 0.05 elseif hotbarInfo then 0.25 else 0.35

	return React.createElement("Frame", {
		BackgroundColor3 = if index % 2 == 0
			then tileBackground
			else tileBackground:Lerp(FOREST_TILE_BACKGROUND_ALT, 0.16),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = index,
		Size = UDim2.fromOffset(TILE_SIZE, TILE_SIZE),
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = if isSelected then 2 else 1,
			Transparency = strokeTransparency,
		}),
		-- Show viewport only if no icon is available
		Viewport = if not icon
			then React.createElement(InventoryItemViewport, {
				Entry = entry,
			})
			else nil,
		-- Show icon if available
		Icon = if icon
			then React.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = icon,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			})
			else nil,
		Name = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = FOREST_LABEL_BACKGROUND,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 24),
			Text = getEntryName(entry),
			TextColor3 = FOREST_TEXT,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		}),
		Detail = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.new(1, -12, 0, 16),
			Text = getEntryDetail(entry),
			TextColor3 = FOREST_MUTED_TEXT,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		}),
		Hotbar = if hotbarInfo
			then React.createElement("TextLabel", {
				BackgroundColor3 = FOREST_LABEL_BACKGROUND,
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(6, 22),
				Size = UDim2.fromOffset(48, 16),
				Text = ("Slot %d"):format(hotbarInfo.Slot),
				TextColor3 = FOREST_ACCENT,
				TextSize = 10,
				TextStrokeColor3 = FOREST_SHADOW,
				TextStrokeTransparency = 0.45,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 4,
			})
			else nil,
		Quantity = if quantityText ~= ""
			then React.createElement("TextLabel", {
				BackgroundColor3 = FOREST_LABEL_BACKGROUND,
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				Position = UDim2.new(1, -30, 0, 5),
				Size = UDim2.fromOffset(24, 16),
				Text = quantityText,
				TextColor3 = FOREST_ACCENT,
				TextSize = 10,
				TextStrokeColor3 = FOREST_SHADOW,
				TextStrokeTransparency = 0.45,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 4,
			})
			else nil,
		SelectButton = React.createElement("TextButton", {
			Active = isInteractive,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0),
			Selectable = isInteractive,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 10,
			[React.Event.Activated] = function()
				if isInteractive then
					onSelected()
				end
			end,
		}),
	})
end

local function getSortedEntries(inventory: InventorySnapshot): { InventoryEntry }
	local entries = {}
	for _, entry in pairs(inventory.Entries) do
		table.insert(entries, entry)
	end

	table.sort(entries, function(left: InventoryEntry, right: InventoryEntry)
		return left.EntryId < right.EntryId
	end)

	return entries
end

local function getDisplayEntries(
	inventory: InventorySnapshot,
	loadout: LoadoutSnapshot
): ({ InventoryEntry }, { [string]: HotbarInfo })
	local entries = getSortedEntries(inventory)
	local hotbarInfoByEntryId = getHotbarInfoByEntryId(entries, loadout)

	table.sort(entries, function(left: InventoryEntry, right: InventoryEntry)
		local leftHotbarInfo = hotbarInfoByEntryId[left.EntryId]
		local rightHotbarInfo = hotbarInfoByEntryId[right.EntryId]
		local leftHotbarSlot = leftHotbarInfo and leftHotbarInfo.Slot or nil
		local rightHotbarSlot = rightHotbarInfo and rightHotbarInfo.Slot or nil

		if leftHotbarSlot and rightHotbarSlot and leftHotbarSlot ~= rightHotbarSlot then
			return leftHotbarSlot < rightHotbarSlot
		end

		if leftHotbarSlot ~= nil and rightHotbarSlot == nil then
			return true
		end

		if leftHotbarSlot == nil and rightHotbarSlot ~= nil then
			return false
		end

		return left.EntryId < right.EntryId
	end)

	return entries, hotbarInfoByEntryId
end

local function buildTiles(
	entries: { InventoryEntry },
	selectedEntryId: string?,
	hotbarInfoByEntryId: { [string]: HotbarInfo },
	layoutOrderOffset: number?,
	isLocked: boolean
)
	local tiles = {}
	local orderOffset = layoutOrderOffset or 0
	for index, entry in ipairs(entries) do
		local hotbarInfo = hotbarInfoByEntryId[entry.EntryId]
		tiles[entry.EntryId] = inventoryTile(
			entry,
			orderOffset + index,
			selectedEntryId == entry.EntryId,
			hotbarInfo,
			function()
				WardrobeSelection.SetSelectedItem(buildSelectedInventoryItem(entry, hotbarInfo))
			end,
			not isLocked
		)
	end

	return tiles
end

local function splitEntriesByCategory(entries: { InventoryEntry }): { [InventoryCategory]: { InventoryEntry } }
	local grouped: { [InventoryCategory]: { InventoryEntry } } = {
		Items = {},
		Consumables = {},
		Armor = {},
		Weapons = {},
	}

	for _, entry in ipairs(entries) do
		table.insert(grouped[getEntryCategory(entry)], entry)
	end

	return grouped
end

local function categoryHeader(text: string, order: number)
	return React.createElement("TextLabel", {
		BackgroundColor3 = FOREST_LABEL_BACKGROUND,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		LayoutOrder = order,
		Size = UDim2.new(1, -2, 0, 20),
		Text = text,
		TextColor3 = FOREST_ACCENT,
		TextSize = 12,
		TextStrokeColor3 = FOREST_SHADOW,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function buildCategoryContent(
	entries: { InventoryEntry },
	selectedEntryId: string?,
	hotbarInfoByEntryId: { [string]: HotbarInfo },
	isLocked: boolean,
	filterMode: InventoryFilterMode
): { [string]: any }
	local grouped = splitEntriesByCategory(entries)
	local children = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, CATEGORY_TILE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local order = 1
	local tileOrderOffset = 0
	local categories = if filterMode == "ItemsOnly"
		then { "Items" }
		else { "Items", "Consumables", "Armor", "Weapons" }
	for _, categoryName in ipairs(categories) do
		local categoryEntries = grouped[categoryName :: InventoryCategory]
		children["Header_" .. categoryName] = categoryHeader(categoryName, order)
		order += 1

		if #categoryEntries == 0 then
			children["Empty_" .. categoryName] = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				LayoutOrder = order,
				Size = UDim2.new(1, -4, 0, 18),
				Text = "No entries",
				TextColor3 = FOREST_MUTED_TEXT,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			order += 1
		else
			local rows = math.ceil(#categoryEntries / GRID_COLUMNS)
			local categoryHeight = rows * TILE_SIZE + math.max(0, rows - 1) * TILE_PADDING
			children["Grid_" .. categoryName] = React.createElement("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, categoryHeight),
			}, {
				Layout = React.createElement("UIGridLayout", {
					CellPadding = UDim2.fromOffset(TILE_PADDING, TILE_PADDING),
					CellSize = UDim2.fromOffset(TILE_SIZE, TILE_SIZE),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Tiles = React.createElement(
					React.Fragment,
					nil,
					buildTiles(categoryEntries, selectedEntryId, hotbarInfoByEntryId, tileOrderOffset, isLocked)
				),
			})
			tileOrderOffset += #categoryEntries
			order += 1
		end
	end

	return children
end

local function WardrobeInventoryPanel(props: {
	IsLocked: boolean?,
	FilterMode: InventoryFilterMode?,
	TitleText: string?,
})
	local inventory, setInventory = React.useState(function()
		return InventoryServiceClient.GetInventory()
	end)
	local loadout, setLoadout = React.useState(function()
		return WeaponServiceClient.GetLoadoutData() :: LoadoutSnapshot
	end)
	local selectedItem, setSelectedItem = React.useState(function()
		return WardrobeSelection.GetSelectedItem()
	end)

	React.useEffect(function()
		local connection = InventoryServiceClient.GetInventoryChangedSignal()
			:Connect(function(nextInventory: InventorySnapshot)
				setInventory(nextInventory)
			end)

		InventoryServiceClient.RequestInventory()
		setInventory(InventoryServiceClient.GetInventory())

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = WeaponServiceClient.GetLoadoutChangedSignal():Connect(function(nextLoadout: LoadoutSnapshot)
			setLoadout(nextLoadout)
		end)

		WeaponServiceClient.RequestLoadout()
		setLoadout(WeaponServiceClient.GetLoadoutData() :: LoadoutSnapshot)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = WardrobeSelection.GetSelectionChangedSignal()
			:Connect(function(nextSelectedItem: SelectedItem?)
				setSelectedItem(nextSelectedItem)
			end)

		setSelectedItem(WardrobeSelection.GetSelectedItem())

		return function()
			connection:Disconnect()
		end
	end, {})

	local entries, hotbarInfoByEntryId = getDisplayEntries(inventory, loadout)
	local isLocked = props.IsLocked == true
	local filterMode = props.FilterMode or "Full"
	local selectedEntryId = if selectedItem and selectedItem.Source == "Inventory" then selectedItem.EntryId else nil
	local visibleEntryCount = 0
	if filterMode == "ItemsOnly" then
		for _, entry in ipairs(entries) do
			if getEntryCategory(entry) == "Items" then
				visibleEntryCount += 1
			end
		end
	else
		visibleEntryCount = #entries
	end
	local gridRowCount = math.max(MIN_GRID_ROWS, math.ceil(visibleEntryCount / GRID_COLUMNS))
	local minimumCanvasHeight = gridRowCount * TILE_SIZE
		+ math.max(0, gridRowCount - 1) * TILE_PADDING
		+ (GRID_INSET * 2)
	local titleSignImageTransparency = if TITLE_SIGN_IMAGE == "" then 1 else 0
	local titleSignBackgroundTransparency = if TITLE_SIGN_IMAGE == "" then 0.18 else 1
	local listChildren = if visibleEntryCount == 0
		then {
			Empty = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Size = UDim2.new(1, 0, 0, 48),
				Text = if filterMode == "ItemsOnly" then "No items" else "No inventory entries",
				TextColor3 = FOREST_MUTED_TEXT,
				TextSize = 18,
			}),
		}
		else buildCategoryContent(entries, selectedEntryId, hotbarInfoByEntryId, isLocked, filterMode)

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Position = UDim2.new(1, -PANEL_RIGHT_MARGIN, 0.5, 0),
		Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
	}, {
		Border = React.createElement(NinePartBorder.Component, {
			Thickness = PANEL_BORDER_THICKNESS,
			UseQuirkyBottomRight = true,
			ZIndex = 8,
		}),

		Inner = React.createElement("Frame", {
			BackgroundColor3 = FOREST_PANEL_BACKGROUND,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(PANEL_INNER_INSET, PANEL_INNER_INSET),
			Size = UDim2.fromOffset(PANEL_CONTENT_WIDTH, PANEL_CONTENT_HEIGHT),
			ZIndex = 1,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = FOREST_PANEL_STROKE,
				Thickness = 1,
				Transparency = 0.32,
			}),
			List = React.createElement("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, minimumCanvasHeight),
				Position = UDim2.fromOffset(0, LIST_TOP),
				ScrollBarImageColor3 = FOREST_PANEL_STROKE,
				ScrollBarThickness = GRID_SCROLLBAR_GUTTER,
				Size = UDim2.new(1, 0, 1, -(LIST_TOP + GRID_INSET)),
				ZIndex = 2,
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, GRID_INSET),
					PaddingLeft = UDim.new(0, GRID_INSET),
					PaddingRight = UDim.new(0, GRID_INSET + GRID_SCROLLBAR_GUTTER),
					PaddingTop = UDim.new(0, GRID_INSET),
				}),
				Content = React.createElement(React.Fragment, nil, listChildren),
			}),
		}),

		TitleSign = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = FOREST_LABEL_BACKGROUND,
			BackgroundTransparency = titleSignBackgroundTransparency,
			BorderSizePixel = 0,
			Image = TITLE_SIGN_IMAGE,
			ImageTransparency = titleSignImageTransparency,
			Position = UDim2.new(0.5, 0, 0, TITLE_SIGN_TOP_Y),
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromOffset(TITLE_SIGN_WIDTH, TITLE_SIGN_HEIGHT),
			ZIndex = 12,
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = FOREST_PANEL_STROKE,
				Thickness = if TITLE_SIGN_IMAGE == "" then 1 else 0,
				Transparency = 0.35,
			}),
			Text = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromScale(0.5, TITLE_SIGN_TEXT_CENTER_Y),
				Size = UDim2.new(1, -24, 0, TITLE_SIGN_TEXT_HEIGHT),
				Text = props.TitleText or "Inventory",
				TextColor3 = FOREST_TEXT,
				TextSize = 22,
				TextStrokeColor3 = FOREST_SHADOW,
				TextStrokeTransparency = 0.55,
				ZIndex = 13,
			}),
		}),
	})
end

return WardrobeInventoryPanel
