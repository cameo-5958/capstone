--!strict

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local NinePartBorder = require(ReplicatedStorage.Classes.UI.NinePartBorder)
local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local WardrobeSelection = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeSelection)

type SelectedItem = WardrobeSelection.SelectedItem

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")

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

type HotbarInfo = {
	Slot: number,
	IsEquipped: boolean,
}

local PANEL_WIDTH = 500
local PANEL_HEIGHT = 560
local PANEL_LEFT_MARGIN = 24
local BORDER_THICKNESS = 24
local CONTENT_PAD = 20
local HEADER_HEIGHT = 38
local PREVIEW_SIZE = 129
local TOP_SECTION_Y = 62
local ACTION_BUTTON_HEIGHT = 20
local TOP_DIVIDER_Y = TOP_SECTION_Y + PREVIEW_SIZE + 16
local ATTRIBUTE_TOP = TOP_DIVIDER_Y + 28
local ATTRIBUTE_HEIGHT = 150
local PASSIVES_TOP = ATTRIBUTE_TOP + ATTRIBUTE_HEIGHT + 18
local ACTION_BAR_X = CONTENT_PAD + PREVIEW_SIZE + 16
local ACTION_BAR_Y = TOP_DIVIDER_Y - ACTION_BUTTON_HEIGHT - 8
local ACTION_BUTTON_GAP = 4
local ACTION_BUTTON_WIDTH = math.floor((PANEL_WIDTH - ACTION_BAR_X - CONTENT_PAD - (ACTION_BUTTON_GAP * 4)) / 5)

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
local SLOT_ACTION_BG = WOOD_HEADER
local SLOT_ACTION_STROKE = GOLD
local SLOT_ACTION_TEXT = Color3.fromRGB(232, 188, 82)
local RED_TAG = Color3.fromRGB(114, 33, 41)
local RARITY_BADGE_COLORS = {
	CRUDE = Color3.fromRGB(82, 84, 84),
	REFINED = Color3.fromRGB(48, 84, 129),
	EXALTED = Color3.fromRGB(132, 89, 34),
	APEX = Color3.fromRGB(126, 28, 32),
}

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

local function titleCase(value: string): string
	if value == "" then
		return value
	end

	return string.upper(string.sub(value, 1, 1)) .. string.lower(string.sub(value, 2))
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
		return "Select a Weapon"
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
	return selectedItem and (selectedItem.Class or selectedItem.Type or data.Class or data.Type or "Weapon") or "Weapon"
end

local function getRarityText(selectedItem: SelectedItem?): string
	local data = getSelectedData(selectedItem)
	local rarity = data.Rarity
	if type(rarity) ~= "string" or rarity == "" then
		return "Crude"
	end

	return titleCase(rarity)
end

local function getRarityBadgeColor(rarityText: string): Color3
	local normalized = string.upper(rarityText)
	if normalized == "COMMON" then
		normalized = "CRUDE"
	end

	return RARITY_BADGE_COLORS[normalized] or RARITY_BADGE_COLORS.CRUDE
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

local function getSelectedDescription(selectedItem: SelectedItem?): string
	if not selectedItem then
		return "Select a weapon to inspect its story and details."
	end

	local data = getSelectedData(selectedItem)
	local description = firstValue(data.Description, data.Desc)
	if type(description) == "string" and description ~= "" then
		return description
	end

	local databaseData = getWeaponDatabaseData(selectedItem)
	local databaseDescription = firstValue(databaseData.Description, databaseData.Desc)
	if type(databaseDescription) == "string" and databaseDescription ~= "" then
		return databaseDescription
	end

	return "No description has been written for this weapon yet."
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

local function getSelectedHotbarInfoForSlot(selectedItem: SelectedItem?, loadout: LoadoutSnapshot, slotNumber: number): HotbarInfo?
	if not selectedItem or selectedItem.ItemKind ~= "Weapon" then
		return nil
	end

	local slot = loadout.Slots[slotNumber]
	if not slotMatchesSelected(slot, selectedItem) then
		return nil
	end

	local resolvedSlotNumber = slot.Slot or slotNumber
	return {
		Slot = resolvedSlotNumber,
		IsEquipped = slot.IsEquipped == true or loadout.EquippedIndex == resolvedSlotNumber,
	}
end

local function canActOnSelectedItem(selectedItem: SelectedItem?): boolean
	return selectedItem ~= nil
		and selectedItem.Source == "Inventory"
		and selectedItem.ItemKind == "Weapon"
		and selectedItem.EntryId ~= nil
end

local function useSelectedSlotAction(selectedItem: SelectedItem?, loadout: LoadoutSnapshot, slotNumber: number): ()
	if not canActOnSelectedItem(selectedItem) then
		return
	end

	local slotHotbarInfo = getSelectedHotbarInfoForSlot(selectedItem, loadout, slotNumber)
	if not slotHotbarInfo and selectedItem and selectedItem.EntryId then
		WeaponServiceClient.EquipInventoryEntryToSlot(selectedItem.EntryId, slotNumber)
	end
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

local function preloadVisualAssets(instance: Instance, context: string): boolean
	local loadedCleanly = true
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ instance }, function(_contentId: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				loadedCleanly = false
			end
		end)
	end)

	if not ok then
		warn(("[WardrobeStats] Failed to preload %s preview assets: %s"):format(context, tostring(err)))
		return false
	end

	if not loadedCleanly then
		warn(("[WardrobeStats] %s preview had assets that did not preload cleanly."):format(context))
	end

	return loadedCleanly
end

local function resolveWeaponModelTemplate(selectedItem: SelectedItem?): Instance?
	if not selectedItem or selectedItem.ItemKind ~= "Weapon" then
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

local function cloneWeaponVisual(selectedItem: SelectedItem?): Model?
	local template = resolveWeaponModelTemplate(selectedItem)
	if not template then
		return nil
	end

	local clone = template:Clone()
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

local function frameWeaponModel(camera: Camera, model: Model): ()
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

local function WeaponPreviewViewport(props: { SelectedItem: SelectedItem? })
	local viewportRef = React.useRef(nil :: ViewportFrame?)
	local selectedItem = props.SelectedItem
	local selectedWeaponId = getSelectedWeaponId(selectedItem) or ""
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
		camera.Name = "WeaponCamera"
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		local weaponModel = cloneWeaponVisual(selectedItem)
		if weaponModel then
			task.spawn(function()
				preloadVisualAssets(weaponModel, selectedName)

				if disposed or viewportRef.current ~= viewport then
					weaponModel:Destroy()
					return
				end

				weaponModel.Parent = worldModel
				frameWeaponModel(camera, weaponModel)
			end)
		end

		return function()
			disposed = true
			if weaponModel and weaponModel.Parent == nil then
				weaponModel:Destroy()
			end

			viewport.CurrentCamera = nil
			worldModel:Destroy()
			camera:Destroy()
		end
	end, { selectedWeaponId, selectedName })

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
		Viewport = React.createElement(WeaponPreviewViewport, {
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

local function flatActionButton(
	name: string,
	text: string,
	index: number,
	isEnabled: boolean,
	isDanger: boolean,
	onActivated: () -> ()
)
	local x = (index - 1) * (ACTION_BUTTON_WIDTH + ACTION_BUTTON_GAP)

	return React.createElement("TextButton", {
		Active = isEnabled,
		AutoButtonColor = isEnabled,
		BackgroundColor3 = if isDanger
			then RED_TAG
			elseif isEnabled then SLOT_ACTION_BG
			else Color3.fromRGB(55, 48, 39),
		BackgroundTransparency = if isEnabled then 0.02 else 0.32,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Name = name,
		Position = UDim2.fromOffset(x, 0),
		Selectable = isEnabled,
		Size = UDim2.fromOffset(ACTION_BUTTON_WIDTH, ACTION_BUTTON_HEIGHT),
		Text = text,
		TextColor3 = if isDanger
			then TEXT_MAIN
			elseif isEnabled then SLOT_ACTION_TEXT
			else TEXT_DIM,
		TextSize = 10,
		ZIndex = 4,
		[React.Event.Activated] = function()
			if isEnabled then
				onActivated()
			end
		end,
	}, {
		Stroke = React.createElement("UIStroke", {
			Color = if isDanger
				then Color3.fromRGB(174, 74, 71)
				elseif isEnabled then SLOT_ACTION_STROKE
				else GOLD_DIM,
			Thickness = 1,
			Transparency = if isEnabled then 0.22 else 0.58,
		}),
	})
end

local function slotActionButton(selectedItem: SelectedItem?, loadout: LoadoutSnapshot, slotNumber: number)
	local canAct = canActOnSelectedItem(selectedItem)
	local slotHotbarInfo = getSelectedHotbarInfoForSlot(selectedItem, loadout, slotNumber)
	local isEnabled = canAct and slotHotbarInfo == nil

	return flatActionButton(("Slot%d"):format(slotNumber), tostring(slotNumber), slotNumber, isEnabled, false, function()
		if isEnabled then
			useSelectedSlotAction(selectedItem, loadout, slotNumber)
		end
	end)
end

local function unequipActionButton(selectedItem: SelectedItem?, hotbarInfo: HotbarInfo?)
	local isEnabled = canActOnSelectedItem(selectedItem) and hotbarInfo ~= nil
	local text = if isEnabled then "Unequip" else ""

	return flatActionButton("Unequip", text, 5, isEnabled, true, function()
		if isEnabled and hotbarInfo then
			WeaponServiceClient.UnequipSlot(hotbarInfo.Slot)
		end
	end)
end

local function slotActionButtons(selectedItem: SelectedItem?, hotbarInfo: HotbarInfo?, loadout: LoadoutSnapshot)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(ACTION_BAR_X, ACTION_BAR_Y),
		Size = UDim2.fromOffset(PANEL_WIDTH - ACTION_BAR_X - CONTENT_PAD, ACTION_BUTTON_HEIGHT),
		ZIndex = 4,
	}, {
		Slot1 = slotActionButton(selectedItem, loadout, 1),
		Slot2 = slotActionButton(selectedItem, loadout, 2),
		Slot3 = slotActionButton(selectedItem, loadout, 3),
		Slot4 = slotActionButton(selectedItem, loadout, 4),
		Unequip = unequipActionButton(selectedItem, hotbarInfo),
	})
end

local function weaponHeader(selectedItem: SelectedItem?, hotbarInfo: HotbarInfo?, loadout: LoadoutSnapshot)
	local data = getSelectedData(selectedItem)
	local baseDamage = if type(data.BaseDamage) == "number" then formatNumber(data.BaseDamage) else "-"
	local weight = if type(data.Weight) == "number" then formatNumber(data.Weight) .. " wt" else "- wt"
	local rarityText = getRarityText(selectedItem)
	local typeText = getSelectedClass(selectedItem)
	local metaX = CONTENT_PAD + PREVIEW_SIZE + 16
	local metaY = TOP_SECTION_Y + 42
	local rarityWidth = 70
	local typeWidth = 64
	local descriptionTop = metaY + 26
	local descriptionHeight = math.max(36, ACTION_BAR_Y - descriptionTop - 8)

	return React.createElement(React.Fragment, nil, {
		Preview = previewBox(selectedItem),
		Name = label(getSelectedName(selectedItem), UDim2.fromOffset(metaX, TOP_SECTION_Y + 8), UDim2.fromOffset(220, 30), {
			Font = Enum.Font.GothamBold,
			TextColor3 = TEXT_MAIN,
			TextSize = 20,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		RarityMeta = metaBadge(rarityText, UDim2.fromOffset(metaX, metaY), rarityWidth, getRarityBadgeColor(rarityText)),
		TypeMeta = metaBadge(typeText, UDim2.fromOffset(metaX + rarityWidth + 6, metaY), typeWidth, Color3.fromRGB(76, 52, 27), GOLD),
		Slot = if hotbarInfo then metaBadge(
			("Slot %d"):format(hotbarInfo.Slot),
			UDim2.fromOffset(metaX + rarityWidth + typeWidth + 12, metaY),
			58,
			Color3.fromRGB(48, 36, 22),
			if hotbarInfo.IsEquipped then GOLD else TEXT_MUTED
		) else nil,
		Description = descriptionBox(
			getSelectedDescription(selectedItem),
			UDim2.fromOffset(metaX, descriptionTop),
			UDim2.fromOffset(PANEL_WIDTH - metaX - CONTENT_PAD, descriptionHeight)
		),
		Damage = label(baseDamage, UDim2.fromOffset(PANEL_WIDTH - CONTENT_PAD - 42, TOP_SECTION_Y + 8), UDim2.fromOffset(42, 24), {
			Font = Enum.Font.GothamBold,
			TextColor3 = GOLD,
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Weight = label(weight, UDim2.fromOffset(PANEL_WIDTH - CONTENT_PAD - 68, TOP_SECTION_Y + 34), UDim2.fromOffset(68, 16), {
			TextColor3 = TEXT_MUTED,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Actions = slotActionButtons(selectedItem, hotbarInfo, loadout),
	})
end

local function attributeDiagram(selectedItem: SelectedItem?)
	local rows = getAttributeRows(selectedItem)
	local hubCenter = Vector2.new(90, 74)
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

local function hasPassiveSection(selectedItem: SelectedItem?): boolean
	if not selectedItem then
		return false
	end

	local data = getSelectedData(selectedItem)
	return #getSelectedPassiveDetails(selectedItem) > 0
		or #getSelectedAbilityDetails(selectedItem) > 0
		or data.HasPassive == true
		or data.HasAbility == true
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
	end

	return cards
end

local function WardrobeStatsPanel()
	local selectedItem, setSelectedItem = React.useState(function()
		return WardrobeSelection.GetSelectedItem()
	end)
	local loadout, setLoadout = React.useState(function()
		return WeaponServiceClient.GetLoadoutData() :: LoadoutSnapshot
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

	local selectedHotbarInfo = getSelectedHotbarInfo(selectedItem, loadout)
	local shouldShowPassives = hasPassiveSection(selectedItem)

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
			Title = label("Weapon Stats", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), {
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
		TopDivider = React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(53, 34, 14),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, TOP_DIVIDER_Y),
			Size = UDim2.new(1, -12, 0, 1),
			ZIndex = 2,
		}),
		BodyShade = React.createElement("Frame", {
			BackgroundColor3 = WOOD_PANEL,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, TOP_DIVIDER_Y + 1),
			Size = UDim2.new(1, -12, 1, -(TOP_DIVIDER_Y + 7)),
			ZIndex = 1,
		}),
		WeaponHeader = weaponHeader(selectedItem, selectedHotbarInfo, loadout),
		AttributesLabel = label("ATTRIBUTES", UDim2.fromOffset(CONTENT_PAD, TOP_DIVIDER_Y + 10), UDim2.fromOffset(120, 18), {
			Font = Enum.Font.GothamBold,
			TextColor3 = TEXT_MUTED,
			TextSize = 10,
		}),
		Attributes = attributeDiagram(selectedItem),
		PassivesDivider = if shouldShowPassives then React.createElement("Frame", {
			BackgroundColor3 = Color3.fromRGB(53, 34, 14),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(6, PASSIVES_TOP - 28),
			Size = UDim2.new(1, -12, 0, 1),
			ZIndex = 2,
		}) else nil,
		PassivesLabel = if shouldShowPassives then label("PASSIVES", UDim2.fromOffset(CONTENT_PAD, PASSIVES_TOP - 18), UDim2.fromOffset(120, 18), {
			Font = Enum.Font.GothamBold,
			TextColor3 = TEXT_MUTED,
			TextSize = 10,
		}) else nil,
		Passives = if shouldShowPassives then React.createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(CONTENT_PAD, PASSIVES_TOP),
			Size = UDim2.new(1, -(CONTENT_PAD * 2), 1, -(PASSIVES_TOP + CONTENT_PAD)),
			ZIndex = 3,
		}, {
			Layout = React.createElement("UIListLayout", {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Cards = React.createElement(React.Fragment, nil, passiveCards(selectedItem)),
		}) else nil,
	})
end

return WardrobeStatsPanel
