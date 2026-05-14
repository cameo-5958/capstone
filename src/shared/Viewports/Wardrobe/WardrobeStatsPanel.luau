--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local NinePartBorder = require(ReplicatedStorage.Classes.UI.NinePartBorder)
local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)
local ItemLoadoutServiceClient = require(ReplicatedStorage.Services.ItemLoadout.ItemLoadoutServiceClient)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local WardrobePreviewLoader = require(ReplicatedStorage.Viewports.Wardrobe.WardrobePreviewLoader)
local WardrobeSelection = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeSelection)

type SelectedItem = WardrobeSelection.SelectedItem

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")
local InventoryItemsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("InventoryItems")

type LoadoutSlot = {
	Slot: number,
	IsEquipped: boolean?,
	InstanceId: string?,
	WeaponId: string?,
}

type LoadoutSnapshot = {
	EquippedIndex: number?,
	Slots: { LoadoutSlot },
}

type ItemLoadoutSlot = {
	Slot: number,
	EntryId: string?,
	ItemId: string?,
	Name: string?,
}

type ItemLoadoutSnapshot = {
	Slots: { ItemLoadoutSlot },
}

type HotbarInfo = {
	Slot: number,
	IsEquipped: boolean,
}

local PANEL_WIDTH = 500
local PANEL_HEIGHT = 420
local PANEL_LEFT_MARGIN = 24
local BORDER_THICKNESS = 24
local CONTENT_PAD = 20
local HEADER_HEIGHT = 38
local PREVIEW_SIZE = 104
local BODY_TOP = HEADER_HEIGHT + 8
local TOP_SECTION_Y = 8
local TOP_SECTION_HEIGHT = PREVIEW_SIZE + 10
local TOP_DIVIDER_Y = TOP_SECTION_Y + TOP_SECTION_HEIGHT + 8
local ATTRIBUTE_LABEL_TOP = TOP_DIVIDER_Y + 10
local ATTRIBUTE_TOP = ATTRIBUTE_LABEL_TOP + 18
local ATTRIBUTE_HEIGHT = 120
local PASSIVES_LABEL_TOP = ATTRIBUTE_TOP + ATTRIBUTE_HEIGHT + 12
local PASSIVES_TOP = PASSIVES_LABEL_TOP + 18
local SCROLLBAR_THICKNESS = 5
local CARD_HEIGHT = 48
local CARD_GAP = 8

local WOOD_DARK = Color3.fromRGB(28, 20, 9)
local WOOD_PANEL = Color3.fromRGB(34, 23, 10)
local WOOD_HEADER = Color3.fromRGB(72, 45, 19)
local GOLD = Color3.fromRGB(221, 156, 27)
local GOLD_DIM = Color3.fromRGB(110, 76, 23)
local TEXT_MAIN = Color3.fromRGB(245, 235, 212)
local TEXT_MUTED = Color3.fromRGB(178, 158, 132)
local TEXT_DIM = Color3.fromRGB(130, 113, 90)
local PREVIEW_BG = Color3.fromRGB(33, 50, 60)
local PASSIVE_BG = Color3.fromRGB(34, 54, 68)
local PASSIVE_STROKE = Color3.fromRGB(77, 108, 130)
local GREEN_TAG = Color3.fromRGB(30, 112, 62)
local RED_TAG = Color3.fromRGB(114, 33, 41)

local function isConsumableKind(itemKind: string?): boolean
	return itemKind == "Consumable" or itemKind == "Item"
end

local function isLoadoutItemKind(itemKind: string?): boolean
	return isConsumableKind(itemKind) or itemKind == "InventoryItem"
end

local function formatNumber(value: any): string
	if type(value) ~= "number" then
		return tostring(value or "-")
	end

	local rounded = math.floor(value + 0.5)
	if math.abs(value - rounded) < 0.05 then
		return tostring(rounded)
	end

	return CombatNumbers.FormatTenth(value)
end

local function formatPercent(value: any): string
	if type(value) ~= "number" then
		return tostring(value or "-")
	end

	local percent = if value <= 1 then value * 100 else value
	return formatNumber(percent) .. "%"
end

local function firstValue(...: any): any
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if value ~= nil then
			return value
		end
	end

	return nil
end

local function getSelectedData(selectedItem: SelectedItem?): { [string]: any }
	return if selectedItem then selectedItem.Data else {}
end

local function getSelectedName(selectedItem: SelectedItem?): string
	if not selectedItem then
		return "Select an Item or Weapon"
	end

	if type(selectedItem.Name) == "string" and selectedItem.Name ~= "" then
		return selectedItem.Name
	end

	if type(selectedItem.Id) == "string" and selectedItem.Id ~= "" then
		return selectedItem.Id
	end

	return selectedItem.ItemKind
end

local function getSelectedClass(selectedItem: SelectedItem?): string
	local data = getSelectedData(selectedItem)
	local inventoryType = if type(data.InventoryData) == "table" and type(data.InventoryData.Type) == "string"
		then data.InventoryData.Type
		else nil
	return selectedItem and (selectedItem.Class or selectedItem.Type or data.Class or data.Type or inventoryType or selectedItem.ItemKind or "Weapon")
		or "Weapon"
end

local function isSelectedWeapon(selectedItem: SelectedItem?): boolean
	return selectedItem ~= nil and selectedItem.ItemKind == "Weapon"
end

local function isSelectedArmor(selectedItem: SelectedItem?): boolean
	return selectedItem ~= nil and selectedItem.ItemKind == "Armor"
end

local function isSelectedItem(selectedItem: SelectedItem?): boolean
	return selectedItem ~= nil and isLoadoutItemKind(selectedItem.ItemKind)
end

local function getEnchantText(selectedItem: SelectedItem?): string
	local data = getSelectedData(selectedItem)
	local enchantLevel = firstValue(data.EnchantLevel, data.EnchantmentLevel, data.Enchants, 0)
	if type(enchantLevel) ~= "number" then
		enchantLevel = 0
	end

	return ("+%d ENCHANTED"):format(enchantLevel)
end

local function getSelectedInstanceId(selectedItem: SelectedItem?): string?
	local data = getSelectedData(selectedItem)
	local instanceId = data.InstanceId
	if type(instanceId) == "string" and instanceId ~= "" then
		return instanceId
	end

	return nil
end

local function getSelectedWeaponId(selectedItem: SelectedItem?): string?
	if not selectedItem then
		return nil
	end

	local data = getSelectedData(selectedItem)
	local weaponId = data.WeaponId
	if type(weaponId) == "string" and weaponId ~= "" then
		return weaponId
	end

	if type(selectedItem.Id) == "string" and selectedItem.Id ~= "" then
		return selectedItem.Id
	end

	return nil
end

local function getWeaponDatabaseData(selectedItem: SelectedItem?): { [string]: any }
	if not isSelectedWeapon(selectedItem) then
		return {}
	end

	local weaponId = getSelectedWeaponId(selectedItem)
	if type(weaponId) ~= "string" or weaponId == "" then
		return {}
	end

	local current: Instance = WeaponsDatabase
	for _, part in ipairs(weaponId:split(".")) do
		local child = current:FindFirstChild(part)
		if not child then
			return {}
		end

		current = child
	end

	local dataModule = current:FindFirstChild("Data")
	if not dataModule or not dataModule:IsA("ModuleScript") then
		return {}
	end

	local ok, databaseData = pcall(require, dataModule)
	if ok and type(databaseData) == "table" then
		return databaseData
	end

	return {}
end

local function getInventoryItemDatabaseData(selectedItem: SelectedItem?): { [string]: any }
	if not selectedItem or selectedItem.ItemKind ~= "InventoryItem" then
		return {}
	end

	local itemId = selectedItem.Data.ItemId
	if type(itemId) ~= "string" or itemId == "" then
		return {}
	end

	local folder = InventoryItemsDatabase:FindFirstChild(itemId)
	if not folder or not folder:IsA("Folder") then
		return {}
	end

	local dataModule = folder:FindFirstChild("Data")
	if not dataModule or not dataModule:IsA("ModuleScript") then
		return {}
	end

	local ok, databaseData = pcall(require, dataModule)
	if ok and type(databaseData) == "table" then
		return databaseData
	end

	return {}
end

local function getSelectedDescription(selectedItem: SelectedItem?): string
	if not selectedItem then
		return "Select an inventory item to inspect details."
	end

	local data = getSelectedData(selectedItem)
	local description = firstValue(data.Description, data.Desc)
	if type(description) == "string" and description ~= "" then
		return description
	end

	for _, databaseData in ipairs({
		getWeaponDatabaseData(selectedItem),
		getInventoryItemDatabaseData(selectedItem),
	}) do
		local databaseDescription = firstValue(databaseData.Description, databaseData.Desc)
		if type(databaseDescription) == "string" and databaseDescription ~= "" then
			return databaseDescription
		end
	end

	return "No description has been written for this item yet."
end

local function slotMatchesSelected(slot: LoadoutSlot?, selectedItem: SelectedItem?): boolean
	if not slot or not selectedItem then
		return false
	end

	local selectedInstanceId = getSelectedInstanceId(selectedItem)
	if selectedInstanceId and slot.InstanceId == selectedInstanceId then
		return true
	end

	local selectedWeaponId = getSelectedWeaponId(selectedItem)
	return selectedWeaponId ~= nil and slot.WeaponId == selectedWeaponId
end

local function getSelectedHotbarInfo(selectedItem: SelectedItem?, loadout: LoadoutSnapshot): HotbarInfo?
	if not selectedItem or selectedItem.ItemKind ~= "Weapon" then
		return nil
	end

	if selectedItem.HotbarSlot then
		local slot = loadout.Slots[selectedItem.HotbarSlot]
		if slotMatchesSelected(slot, selectedItem) then
			local slotNumber = slot.Slot or selectedItem.HotbarSlot
			return {
				Slot = slotNumber,
				IsEquipped = slot.IsEquipped == true or loadout.EquippedIndex == slotNumber,
			}
		end
	end

	local selectedInstanceId = getSelectedInstanceId(selectedItem)
	if selectedInstanceId then
		for index = 1, 4 do
			local slot = loadout.Slots[index]
			if slot and slot.InstanceId == selectedInstanceId then
				local slotNumber = slot.Slot or index
				return {
					Slot = slotNumber,
					IsEquipped = slot.IsEquipped == true or loadout.EquippedIndex == slotNumber,
				}
			end
		end
	end

	local selectedWeaponId = getSelectedWeaponId(selectedItem)
	if selectedWeaponId then
		for index = 1, 4 do
			local slot = loadout.Slots[index]
			if slot and slot.WeaponId == selectedWeaponId then
				local slotNumber = slot.Slot or index
				return {
					Slot = slotNumber,
					IsEquipped = slot.IsEquipped == true or loadout.EquippedIndex == slotNumber,
				}
			end
		end
	end

	return nil
end

local function getSelectedItemSlot(selectedItem: SelectedItem?, loadout: ItemLoadoutSnapshot): number?
	if not selectedItem or not isLoadoutItemKind(selectedItem.ItemKind) then
		return nil
	end

	local entryId = selectedItem.EntryId
	if type(entryId) ~= "string" or entryId == "" then
		return nil
	end

	for index, slot in ipairs(loadout.Slots) do
		if slot and slot.EntryId == entryId then
			return slot.Slot or index
		end
	end

	return nil
end

local function canActOnSelectedItem(selectedItem: SelectedItem?): boolean
	return selectedItem ~= nil
		and selectedItem.Source == "Inventory"
		and selectedItem.EntryId ~= nil
end

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

local function line(position: UDim2, size: UDim2, rotation: number?)
	return React.createElement("Frame", {
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Position = position,
		Rotation = rotation or 0,
		Size = size,
		ZIndex = 3,
	})
end

local function statLine(fromPoint: Vector2, toPoint: Vector2, color: Color3, thickness: number, transparency: number?)
	local delta = toPoint - fromPoint
	local length = delta.Magnitude
	local rotation = math.deg(math.atan2(delta.Y, delta.X))

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(fromPoint.X, fromPoint.Y),
		Rotation = rotation,
		Size = UDim2.fromOffset(length, thickness),
		ZIndex = 3,
	})
end

local function statValueRich(labelText: string, valueText: string): string
	return ('<font color="rgb(174,158,134)">%s</font> <font color="rgb(245,235,212)">%s</font>'):format(labelText, valueText)
end

local function getAttributeRows(selectedItem: SelectedItem?)
	if not selectedItem then
		return {}
	end

	local data = getSelectedData(selectedItem)
	local grantedStats = if type(data.GrantedStats) == "table" then data.GrantedStats else {}

	local secondaryStatOrder = {
		{ Key = "Defense", Label = "Defense", Format = formatNumber },
		{ Key = "PhysicalAttack", Label = "Phys ATK", Format = formatNumber },
		{ Key = "MagicalAttack", Label = "Magic ATK", Format = formatNumber },
		{ Key = "PhysicalDamage", Label = "Phys Dmg", Format = formatNumber },
		{ Key = "MagicDamage", Label = "Magic Dmg", Format = formatNumber },
		{ Key = "CritRate", Label = "Crit Rate", Format = formatPercent },
		{ Key = "CritDamage", Label = "Crit Dmg", Format = formatNumber },
		{ Key = "Speed", Label = "ATK Speed", Format = formatNumber },
	}

	local rows = {}
	for _, definition in ipairs(secondaryStatOrder) do
		local value = grantedStats[definition.Key]
		if value ~= nil then
			table.insert(rows, {
				Label = definition.Label,
				Value = definition.Format(value),
			})
		end
	end

	return rows
end

local function resolveWeaponModelTemplate(selectedItem: SelectedItem?): Instance?
	if not isSelectedWeapon(selectedItem) then
		return nil
	end

	local weaponId = getSelectedWeaponId(selectedItem)
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
		if child.Name ~= "Data" and (child:IsA("Tool") or child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder")) then
			return child
		end
	end

	return nil
end

local function buildInventoryItemModel(selectedItem: SelectedItem?): Model?
	if not selectedItem or selectedItem.ItemKind ~= "InventoryItem" then
		return nil
	end

	local itemId = selectedItem.Data.ItemId
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

local function cloneSelectedVisual(selectedItem: SelectedItem?): Model?
	local clone: Instance? = nil
	if isSelectedWeapon(selectedItem) then
		local template = resolveWeaponModelTemplate(selectedItem)
		if template then
			clone = template:Clone()
		end
	elseif selectedItem and selectedItem.ItemKind == "InventoryItem" then
		clone = buildInventoryItemModel(selectedItem)
	end

	if not clone then
		return nil
	end

	prepVisualClone(clone)

	if clone:IsA("Model") then
		return clone
	end

	local previewModel = Instance.new("Model")
	previewModel.Name = "StatsWeaponPreview"

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

local function framePreviewModel(camera: Camera, model: Model): ()
	model:PivotTo(CFrame.Angles(0, math.rad(-35), math.rad(-12)))

	local boundingCFrame, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z, 1) * 0.5
	local focus = boundingCFrame.Position
	local fieldOfView = 30
	local distance = (radius / math.tan(math.rad(fieldOfView) * 0.5)) * 1.28
	local cameraPosition = focus + Vector3.new(radius * 0.65, radius * 0.12, distance)

	camera.CFrame = CFrame.lookAt(cameraPosition, focus)
	camera.FieldOfView = fieldOfView
end

local function SelectedItemPreviewViewport(props: { SelectedItem: SelectedItem? })
	local viewportRef = React.useRef(nil :: ViewportFrame?)
	local selectedItem = props.SelectedItem
	local selectedItemId = if isSelectedWeapon(selectedItem)
		then getSelectedWeaponId(selectedItem) or ""
		elseif selectedItem and type(selectedItem.Data.ItemId) == "string" then selectedItem.Data.ItemId
		else ""
	local selectedName = getSelectedName(selectedItem)

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

		local previewModel = cloneSelectedVisual(selectedItem)
		if previewModel then
			task.spawn(function()
				WardrobePreviewLoader.PreloadInstanceAssets(previewModel)

				if disposed or viewportRef.current ~= viewport then
					previewModel:Destroy()
					return
				end

				previewModel.Parent = worldModel
				framePreviewModel(camera, previewModel)
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
	end, { selectedItem and selectedItem.ItemKind or "", selectedItemId, selectedName })

	return React.createElement("ViewportFrame", {
		ref = viewportRef,
		Ambient = Color3.fromRGB(180, 190, 205),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LightColor = Color3.fromRGB(255, 248, 232),
		LightDirection = Vector3.new(-0.35, -0.7, -0.45),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	})
end

local function previewBox(selectedItem: SelectedItem?)
	return React.createElement("Frame", {
		BackgroundColor3 = PREVIEW_BG,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(CONTENT_PAD, TOP_SECTION_Y + 8),
		Size = UDim2.fromOffset(PREVIEW_SIZE, PREVIEW_SIZE),
		ZIndex = 3,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = GOLD,
			Thickness = 1,
			Transparency = 0.1,
		}),
		Viewport = React.createElement(SelectedItemPreviewViewport, {
			SelectedItem = selectedItem,
		}),
	})
end

local function metaBadge(text: string, position: UDim2, width: number, backgroundColor: Color3, textColor: Color3?)
	return React.createElement("Frame", {
		BackgroundColor3 = backgroundColor,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.fromOffset(width, 18),
		ZIndex = 4,
	}, {
		Text = label(text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), {
			Font = Enum.Font.GothamBold,
			TextColor3 = textColor or TEXT_MAIN,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5,
		}),
	})
end

local function descriptionBox(text: string, position: UDim2, size: UDim2)
	return React.createElement("Frame", {
		BackgroundColor3 = WOOD_PANEL,
		BackgroundTransparency = 0.16,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		ZIndex = 3,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = GOLD_DIM,
			Thickness = 1,
			Transparency = 0.35,
		}),
		Text = label(text, UDim2.fromOffset(8, 4), UDim2.new(1, -16, 1, -8), {
			Font = Enum.Font.Gotham,
			TextColor3 = TEXT_MUTED,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 4,
		}),
	})
end

local function headerActionButton(
	name: string,
	text: string,
	position: UDim2,
	width: number,
	isEnabled: boolean,
	onActivated: () -> ()
)
	return React.createElement("TextButton", {
		Active = isEnabled,
		AutoButtonColor = isEnabled,
		BackgroundColor3 = if isEnabled then WOOD_HEADER else Color3.fromRGB(55, 48, 39),
		BackgroundTransparency = if isEnabled then 0.02 else 0.32,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Name = name,
		Position = position,
		Selectable = isEnabled,
		Size = UDim2.fromOffset(width, 18),
		Text = text,
		TextColor3 = if isEnabled then Color3.fromRGB(232, 188, 82) else TEXT_DIM,
		TextSize = 10,
		ZIndex = 4,
		[React.Event.Activated] = function()
			if isEnabled then
				onActivated()
			end
		end,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = if isEnabled then GOLD else GOLD_DIM,
			Thickness = 1,
			Transparency = if isEnabled then 0.22 else 0.58,
		}),
	})
end

local function itemEquipOptions(
	position: UDim2,
	canAct: boolean,
	selectedSlot: number?,
	onEquipSlot: (number) -> (),
	onUnequipSlot: (number) -> ()
)
	local function slotButton(slot: number, positionX: number)
		local isSelected = selectedSlot == slot
		local text = if isSelected then ("E%d"):format(slot) else tostring(slot)

		return headerActionButton(("ItemSlot%d"):format(slot), text, UDim2.fromOffset(positionX, 0), 22, canAct, function()
			if isSelected then
				onUnequipSlot(slot)
			else
				onEquipSlot(slot)
			end
		end)
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.fromOffset(88, 18),
		ZIndex = 4,
	}, {
		EquipLabel = label("Equip", UDim2.fromOffset(0, 0), UDim2.fromOffset(34, 18), {
			Font = Enum.Font.GothamBold,
			TextColor3 = GOLD,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		SlotOne = slotButton(1, 36),
		SlotTwo = slotButton(2, 62),
	})
end

local function weaponHeader(
	selectedItem: SelectedItem?,
	hotbarInfo: HotbarInfo?,
	selectedItemSlot: number?,
	isLocked: boolean,
	onEquipItemSlot: (number) -> (),
	onUnequipItemSlot: (number) -> ()
)
	local data = getSelectedData(selectedItem)
	local damageText = if type(data.BaseDamage) == "number" then formatNumber(data.BaseDamage) else "-"
	local typeText = getSelectedClass(selectedItem)
	local canAct = canActOnSelectedItem(selectedItem) and not isLocked
	local isWeapon = isSelectedWeapon(selectedItem)
	local isItem = isSelectedItem(selectedItem)
	local isArmor = isSelectedArmor(selectedItem)
	local metaX = CONTENT_PAD + PREVIEW_SIZE + 16
	local metaY = TOP_SECTION_Y + 42
	local actionWidth = if isItem then 88 else 70
	local typeWidth = 64
	local descriptionTop = metaY + 26
	local descriptionHeight = math.max(36, TOP_DIVIDER_Y - descriptionTop - 8)
	local equipText = if isWeapon then (if hotbarInfo then "Equipped" else "Equip") elseif isArmor then "Equip" else ""
	local equipEnabled = canAct and ((isWeapon and hotbarInfo == nil) or isArmor)

	return React.createElement(React.Fragment, nil, {
		Preview = previewBox(selectedItem),
		Name = label(getSelectedName(selectedItem), UDim2.fromOffset(metaX, TOP_SECTION_Y + 8), UDim2.fromOffset(220, 30), {
			Font = Enum.Font.GothamBold,
			TextColor3 = TEXT_MAIN,
			TextSize = 20,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Equip = if isItem
			then itemEquipOptions(UDim2.fromOffset(metaX, metaY), canAct, selectedItemSlot, onEquipItemSlot, onUnequipItemSlot)
			else headerActionButton("EquipAction", equipText, UDim2.fromOffset(metaX, metaY), actionWidth, equipEnabled, function()
				if not selectedItem or not selectedItem.EntryId then
					return
				end

				if isWeapon and hotbarInfo == nil then
					WeaponServiceClient.EquipInventoryEntry(selectedItem.EntryId)
				end
			end),
		TypeMeta = metaBadge(typeText, UDim2.fromOffset(metaX + actionWidth + 6, metaY), typeWidth, Color3.fromRGB(76, 52, 27), GOLD),
		Slot = if hotbarInfo then metaBadge(
			("Slot %d"):format(hotbarInfo.Slot),
			UDim2.fromOffset(metaX + actionWidth + typeWidth + 12, metaY),
			58,
			Color3.fromRGB(48, 36, 22),
			if hotbarInfo.IsEquipped then GOLD else TEXT_MUTED
		) else nil,
		Description = descriptionBox(
			getSelectedDescription(selectedItem),
			UDim2.fromOffset(metaX, descriptionTop),
			UDim2.fromOffset(PANEL_WIDTH - metaX - CONTENT_PAD, descriptionHeight)
		),
		Damage = if isWeapon then label(
			("Damage: %s"):format(damageText),
			UDim2.fromOffset(PANEL_WIDTH - CONTENT_PAD - 125, TOP_SECTION_Y + 10),
			UDim2.fromOffset(125, 24),
			{
			Font = Enum.Font.GothamBold,
			TextColor3 = GOLD,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
		}
		) else nil,
	})
end

local function attributeDiagram(selectedItem: SelectedItem?)
	local rows = getAttributeRows(selectedItem)
	local frameHeight = ATTRIBUTE_HEIGHT
	local hubCenter = Vector2.new(90, math.floor(frameHeight * 0.5))
	local hubRadius = 46
	local hubStroke = 3
	local lineEndX = 278
	local labelX = 292
	local children = {
		SemiCircleClip = React.createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(hubCenter.X, hubCenter.Y - hubRadius - hubStroke),
			Size = UDim2.fromOffset(hubRadius + hubStroke, (hubRadius * 2) + (hubStroke * 2)),
			ZIndex = 4,
		}, {
			Circle = React.createElement("Frame", {
				BackgroundColor3 = WOOD_PANEL,
				BackgroundTransparency = 0.72,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(-hubRadius, hubStroke),
				Size = UDim2.fromOffset(hubRadius * 2, hubRadius * 2),
				ZIndex = 4,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				Stroke = React.createElement("UIStroke", {
					Color = GOLD,
					Thickness = hubStroke,
					Transparency = 0.05,
				}),
			}),
		}),
		SemiCircleDiameter = React.createElement("Frame", {
			BackgroundColor3 = GOLD,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(hubCenter.X - math.floor(hubStroke / 2), hubCenter.Y - hubRadius),
			Size = UDim2.fromOffset(hubStroke, hubRadius * 2),
			ZIndex = 6,
		}),
		HubDot = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(hubCenter.X, hubCenter.Y),
			Size = UDim2.fromOffset(12, 12),
			ZIndex = 7,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Outer = React.createElement("UIStroke", {
				Color = GOLD_DIM,
				Thickness = 4,
				Transparency = 0.15,
			}),
		}),
	}

	for index, row in ipairs(rows) do
		local spacing = if #rows <= 1 then 0 else math.min(30, 88 / (#rows - 1))
		local firstY = hubCenter.Y - (spacing * (#rows - 1) * 0.5)
		local y = firstY + ((index - 1) * spacing)
		local labelY = y - 11
		local normalizedY = math.clamp((y - hubCenter.Y) / hubRadius, -0.92, 0.92)
		local startX = hubCenter.X + math.sqrt(1 - (normalizedY * normalizedY)) * hubRadius
		local lineStart = Vector2.new(startX, y)
		local lineEnd = Vector2.new(lineEndX, y)
		local lineColor = if index <= 2 then GOLD else GOLD_DIM

		children["StatLine" .. index] = statLine(lineStart, lineEnd, lineColor, if index <= 2 then 3 else 2, if index <= 2 then 0 else 0.24)
		children["Dot" .. index] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = GOLD_DIM,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(lineEnd.X, lineEnd.Y),
			Size = UDim2.fromOffset(7, 7),
			ZIndex = 4,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		})
		children["Label" .. index] = label(statValueRich(row.Label, row.Value), UDim2.fromOffset(labelX, labelY), UDim2.fromOffset(120, 22), {
			Font = Enum.Font.GothamBold,
			RichText = true,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(CONTENT_PAD, ATTRIBUTE_TOP),
		Size = UDim2.new(1, -(CONTENT_PAD * 2), 0, ATTRIBUTE_HEIGHT),
		ZIndex = 2,
	}, children)
end

local function passiveCard(layoutOrder: number, tagText: string, tagColor: Color3, title: string, body: string)
	return React.createElement("Frame", {
		BackgroundColor3 = PASSIVE_BG,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 48),
		ZIndex = 3,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = PASSIVE_STROKE,
			Thickness = 1,
			Transparency = 0.12,
		}),
		Tag = React.createElement("Frame", {
			BackgroundColor3 = tagColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(48, 14),
			ZIndex = 4,
		}, {
			Text = label(tagText, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), {
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.fromRGB(176, 244, 192),
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 5,
			}),
		}),
		Title = label(title, UDim2.fromOffset(70, 8), UDim2.new(1, -84, 0, 20), {
			Font = Enum.Font.GothamBold,
			TextColor3 = TEXT_MAIN,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Body = label(body, UDim2.fromOffset(12, 28), UDim2.new(1, -24, 0, 16), {
			TextColor3 = Color3.fromRGB(188, 201, 210),
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
	})
end

local function normalizeDetailList(value: any): { { [string]: any } }
	if type(value) ~= "table" then
		return {}
	end

	local details = {}
	if value[1] ~= nil then
		for _, detail in ipairs(value) do
			if type(detail) == "table" then
				table.insert(details, detail)
			end
		end
	else
		table.insert(details, value)
	end

	return details
end

local function getPassiveDefinitionDetails(databaseData: { [string]: any }): { { [string]: any } }
	local weaponPassive = databaseData.WeaponPassive
	if type(weaponPassive) ~= "table" then
		return {}
	end

	return normalizeDetailList(
		weaponPassive.Metadata
			or weaponPassive.Details
			or weaponPassive.Display
			or weaponPassive.PassiveDetails
	)
end

local function getSelectedPassiveDetails(selectedItem: SelectedItem?): { { [string]: any } }
	local data = getSelectedData(selectedItem)
	local details = normalizeDetailList(firstValue(data.PassiveDetails, data.Passives))
	if #details > 0 then
		return details
	end

	local databaseData = getWeaponDatabaseData(selectedItem)
	details = normalizeDetailList(firstValue(databaseData.PassiveDetails, databaseData.Passives))
	if #details > 0 then
		return details
	end

	return getPassiveDefinitionDetails(databaseData)
end

local function getSelectedAbilityDetails(selectedItem: SelectedItem?): { { [string]: any } }
	local data = getSelectedData(selectedItem)
	local details = normalizeDetailList(firstValue(data.AbilityDetails, data.Abilities))
	if #details > 0 then
		return details
	end

	local databaseData = getWeaponDatabaseData(selectedItem)
	return normalizeDetailList(firstValue(databaseData.AbilityDetails, databaseData.Abilities))
end

local function getDetailTitle(detail: { [string]: any }, fallback: string): string
	local title = firstValue(detail.Name, detail.Title, detail.Id)
	if type(title) == "string" and title ~= "" then
		return title
	end

	return fallback
end

local function getDetailTag(detail: { [string]: any }, fallback: string): string
	local tag = firstValue(detail.Tag, detail.Kind)
	if type(tag) == "string" and tag ~= "" then
		return tag
	end

	return fallback
end

local function getDetailBody(detail: { [string]: any }, fallback: string): string
	local body = firstValue(detail.Description, detail.Desc, detail.Body)
	if type(body) == "string" and body ~= "" then
		return body
	end

	return fallback
end

local function passiveCards(selectedItem: SelectedItem?)
	local data = getSelectedData(selectedItem)
	local passiveDetails = getSelectedPassiveDetails(selectedItem)
	local abilityDetails = getSelectedAbilityDetails(selectedItem)
	local cards = {}
	local order = 1

	for _, detail in ipairs(passiveDetails) do
		cards["Passive" .. order] = passiveCard(
			order,
			getDetailTag(detail, "Passive"),
			GREEN_TAG,
			getDetailTitle(detail, "Weapon Passive"),
			getDetailBody(detail, "Passive details are not serialized yet.")
		)
		order += 1
	end

	if data.HasPassive == true and #passiveDetails == 0 then
		cards.PassiveFallback = passiveCard(order, "Passive", GREEN_TAG, "Weapon Passive", "Passive details are not serialized yet.")
		order += 1
	end

	for _, detail in ipairs(abilityDetails) do
		cards["Ability" .. order] = passiveCard(
			order,
			getDetailTag(detail, "On Hit"),
			RED_TAG,
			getDetailTitle(detail, "Weapon Ability"),
			getDetailBody(detail, "Ability details are not serialized yet.")
		)
		order += 1
	end

	if data.HasAbility == true and #abilityDetails == 0 then
		cards.AbilityFallback = passiveCard(order, "On Hit", RED_TAG, "Weapon Ability", "Ability details are not serialized yet.")
		order += 1
	end

	if order == 1 then
		cards.None = passiveCard(
			order,
			"None",
			Color3.fromRGB(78, 78, 78),
			"No Abilities",
			if selectedItem then "No abilities are configured for this selection." else "Select an item to inspect abilities."
		)
	end

	return cards
end

local function countCards(cards: { [string]: any }): number
	local total = 0
	for _ in pairs(cards) do
		total += 1
	end
	return total
end

local function WardrobeStatsPanel(props: { IsLocked: boolean? })
	local selectedItem, setSelectedItem = React.useState(function()
		return WardrobeSelection.GetSelectedItem()
	end)
	local loadout, setLoadout = React.useState(function()
		return WeaponServiceClient.GetLoadoutData() :: LoadoutSnapshot
	end)
	local itemLoadout, setItemLoadout = React.useState(function()
		return ItemLoadoutServiceClient.GetLoadoutData() :: ItemLoadoutSnapshot
	end)

	React.useEffect(function()
		local connection = WardrobeSelection.GetSelectionChangedSignal():Connect(function(nextSelectedItem: SelectedItem?)
			setSelectedItem(nextSelectedItem)
		end)

		setSelectedItem(WardrobeSelection.GetSelectedItem())

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
		local connection = ItemLoadoutServiceClient.GetLoadoutChangedSignal():Connect(function(nextLoadout: ItemLoadoutSnapshot)
			setItemLoadout(nextLoadout)
		end)

		ItemLoadoutServiceClient.RequestLoadout()
		setItemLoadout(ItemLoadoutServiceClient.GetLoadoutData() :: ItemLoadoutSnapshot)

		return function()
			connection:Disconnect()
		end
	end, {})

	local selectedHotbarInfo = getSelectedHotbarInfo(selectedItem, loadout)
	local selectedItemSlot = getSelectedItemSlot(selectedItem, itemLoadout)
	local isLocked = props.IsLocked == true
	local shouldShowAttributes = selectedItem ~= nil and not isSelectedItem(selectedItem)
	local passiveCardElements = passiveCards(selectedItem)
	local passiveCardCount = countCards(passiveCardElements)
	local passiveListHeight = math.max(56, passiveCardCount * CARD_HEIGHT + math.max(0, passiveCardCount - 1) * CARD_GAP)
	local passivesLabelTop = if shouldShowAttributes then PASSIVES_LABEL_TOP else ATTRIBUTE_LABEL_TOP
	local passivesTop = if shouldShowAttributes then PASSIVES_TOP else ATTRIBUTE_TOP
	local contentHeight = passivesTop + passiveListHeight + CONTENT_PAD
	local equipSelectedItemToSlot = function(slot: number)
		if not selectedItem then
			return
		end

		local entryId = selectedItem.EntryId
		if not isLoadoutItemKind(selectedItem.ItemKind) or type(entryId) ~= "string" or entryId == "" then
			return
		end

		ItemLoadoutServiceClient.EquipInventoryEntryToSlot(entryId, slot)
	end
	local unequipItemSlot = function(slot: number)
		ItemLoadoutServiceClient.UnequipSlot(slot)
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
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
			Title = label("Item & Weapon Stats", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), {
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
		BodyShade = React.createElement("Frame", {
			BackgroundColor3 = WOOD_PANEL,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, HEADER_HEIGHT + 7),
			Size = UDim2.new(1, -12, 1, -(HEADER_HEIGHT + 13)),
			ZIndex = 1,
		}),
		ContentScroll = React.createElement("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.None,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, contentHeight),
			Position = UDim2.fromOffset(0, BODY_TOP),
			ScrollBarImageColor3 = GOLD_DIM,
			ScrollBarThickness = SCROLLBAR_THICKNESS,
			Size = UDim2.new(1, 0, 1, -BODY_TOP),
			ZIndex = 2,
		}, {
			Content = React.createElement("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, contentHeight),
				ZIndex = 2,
			}, {
				TopDivider = React.createElement("Frame", {
					BackgroundColor3 = Color3.fromRGB(53, 34, 14),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(6, TOP_DIVIDER_Y),
					Size = UDim2.new(1, -12, 0, 1),
					ZIndex = 2,
				}),
				WeaponHeader = weaponHeader(
					selectedItem,
					selectedHotbarInfo,
					selectedItemSlot,
					isLocked,
					equipSelectedItemToSlot,
					unequipItemSlot
				),
				AttributesLabel = if shouldShowAttributes then label("ATTRIBUTES", UDim2.fromOffset(CONTENT_PAD, ATTRIBUTE_LABEL_TOP), UDim2.fromOffset(120, 18), {
					Font = Enum.Font.GothamBold,
					TextColor3 = TEXT_MUTED,
					TextSize = 10,
				}) else nil,
				Attributes = if shouldShowAttributes then attributeDiagram(selectedItem) else nil,
				PassivesDivider = if shouldShowAttributes then React.createElement("Frame", {
					BackgroundColor3 = Color3.fromRGB(53, 34, 14),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(6, passivesLabelTop - 10),
					Size = UDim2.new(1, -12, 0, 1),
					ZIndex = 2,
				}) else nil,
				PassivesLabel = label("ABILITIES", UDim2.fromOffset(CONTENT_PAD, passivesLabelTop), UDim2.fromOffset(120, 18), {
					Font = Enum.Font.GothamBold,
					TextColor3 = TEXT_MUTED,
					TextSize = 10,
				}),
				Passives = React.createElement("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(CONTENT_PAD, passivesTop),
					Size = UDim2.new(1, -(CONTENT_PAD * 2) - SCROLLBAR_THICKNESS, 0, passiveListHeight),
					ZIndex = 3,
				}, {
					Layout = React.createElement("UIListLayout", {
						Padding = UDim.new(0, CARD_GAP),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Cards = React.createElement(React.Fragment, nil, passiveCardElements),
				}),
			}),
		}),
	})
end

return WardrobeStatsPanel
