--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ItemRegistry = require(ReplicatedStorage.Database.Items.Registry)
local InventoryItemRegistry = nil :: any
local InventoryServiceServer = nil :: any

type StackGrant = {
	ItemKind: string,
	StackKey: string,
	Quantity: number,
	MaxStack: number?,
	Data: { [string]: any }?,
}

type DropState = {
	Id: string,
	Model: Model,
}

local ItemDropServiceServer = {}
local DropRoot: Folder? = nil
local ActiveDrops: { [string]: DropState } = {}

local PICKED_UP_STORAGE_SECTION = "PickedUp"

local function getInventoryItemRegistry()
	if InventoryItemRegistry == nil then
		InventoryItemRegistry = require(ReplicatedStorage.Database.InventoryItems.Registry)
	end
	return InventoryItemRegistry
end

local function getInventoryServiceServer()
	if InventoryServiceServer == nil then
		InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
	end
	return InventoryServiceServer
end

local function cloneData(data: { [string]: any }?): { [string]: any }
	local clone = {}
	if not data then
		return clone
	end

	for key, value in pairs(data) do
		clone[key] = value
	end
	return clone
end

local function ensureDropRoot(): Folder
	if DropRoot and DropRoot.Parent then
		return DropRoot
	end

	local worldRoot = Workspace:FindFirstChild("WorldService")
	if not worldRoot then
		worldRoot = Instance.new("Folder")
		worldRoot.Name = "WorldService"
		worldRoot.Parent = Workspace
	end

	local runtimeRoot = worldRoot:FindFirstChild("RuntimeSpawns")
	if runtimeRoot and not runtimeRoot:IsA("Folder") then
		runtimeRoot:Destroy()
		runtimeRoot = nil
	end
	if not runtimeRoot then
		runtimeRoot = Instance.new("Folder")
		runtimeRoot.Name = "RuntimeSpawns"
		runtimeRoot.Parent = worldRoot
	end

	local drops = runtimeRoot:FindFirstChild("ItemDrops")
	if drops and not drops:IsA("Folder") then
		drops:Destroy()
		drops = nil
	end
	if not drops then
		drops = Instance.new("Folder")
		drops.Name = "ItemDrops"
		drops.Parent = runtimeRoot
	end

	DropRoot = drops :: Folder
	return DropRoot
end

local function normalizeItemKind(itemKind: string): string
	if itemKind == "Item" then
		return "Consumable"
	end
	return itemKind
end

local function buildConsumableData(grant: StackGrant): { [string]: any }
	local data = cloneData(grant.Data)
	local itemId = data.ItemId
	if type(itemId) == "string" and itemId ~= "" then
		local definition = ItemRegistry.Get(itemId)
		if definition then
			data.Kind = "Consumable"
			data.ItemId = definition.Id
			data.Name = definition.Name
			data.Desc = definition.Desc
			data.Icon = definition.Icon
			data.MaxStack = definition.MaxStack
			data.SpawnWith = definition.SpawnWith
			data.StackKey = definition.StackKey or ("Item:" .. definition.Id)
			data.InventoryData = definition.InventoryData or {}
			data.Effects = definition.Effects
		end
	end

	return data
end

local function buildInventoryItemData(grant: StackGrant): { [string]: any }
	local data = cloneData(grant.Data)
	local itemId = data.ItemId
	if type(itemId) == "string" and itemId ~= "" then
		local definition = getInventoryItemRegistry().Get(itemId)
		if definition then
			data.Kind = "Item"
			data.ItemId = definition.Id
			data.Name = definition.Name
			data.Desc = definition.Desc
			data.Icon = definition.Icon
			data.MaxStack = definition.MaxStack
			data.SpawnWith = definition.SpawnWith
			data.StackKey = "InventoryItem:" .. definition.Id
			data.CanEquip = definition.CanEquip
			data.CanUse = definition.CanUse
			data.EquipSlotType = definition.EquipSlotType
			data.ModelAssetName = definition.ModelAssetName
			data.InventoryData = definition.InventoryData or {}
			data.UseEffects = definition.UseEffects
		end
	end

	return data
end

local function resolveDropText(itemKind: string, data: { [string]: any }, stackKey: string): string
	local displayName = data.DisplayName or data.Name
	if type(displayName) == "string" and displayName ~= "" then
		return displayName
	end

	local itemId = data.ItemId
	if type(itemId) == "string" and itemId ~= "" then
		return itemId
	end

	if itemKind == "Weapon" then
		local weaponPath = data.WeaponPath
		if type(weaponPath) == "string" and weaponPath ~= "" then
			return weaponPath
		end
	end

	return stackKey
end

local function buildDropModel(dropId: string, position: Vector3, displayText: string, quantity: number, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Drop_" .. dropId
	model:SetAttribute("DropId", dropId)

	local anchor = Instance.new("Part")
	anchor.Name = "DropAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Material = Enum.Material.Neon
	anchor.Color = color
	anchor.Shape = Enum.PartType.Ball
	anchor.Size = Vector3.new(1.2, 1.2, 1.2)
	anchor.Position = position + Vector3.new(0, 1.6, 0)
	anchor.Parent = model

	local ring = Instance.new("Part")
	ring.Name = "DropRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = color:Lerp(Color3.new(1, 1, 1), 0.2)
	ring.Transparency = 0.35
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.18, 2.6, 2.6)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DropLabel"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.ExtentsOffset = Vector3.new(0, 1.6, 0)
	billboard.Size = UDim2.fromOffset(180, 44)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = if quantity > 1 then string.format("%s x%d", displayText, quantity) else displayText
	label.TextColor3 = Color3.fromRGB(244, 234, 205)
	label.TextSize = 14
	label.TextStrokeColor3 = Color3.fromRGB(41, 26, 16)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = displayText
	prompt.HoldDuration = 0.08
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	model.PrimaryPart = anchor
	model.Parent = ensureDropRoot()
	return model
end

local function removeDrop(dropId: string)
	local state = ActiveDrops[dropId]
	if not state then
		return
	end

	ActiveDrops[dropId] = nil
	if state.Model.Parent then
		state.Model:Destroy()
	end
end

function ItemDropServiceServer.DropStackGrant(position: Vector3, grant: StackGrant): string?
	local quantity = math.max(0, math.floor(grant.Quantity))
	if quantity <= 0 then
		return nil
	end

	local normalizedItemKind = normalizeItemKind(grant.ItemKind)
	local resolvedData = if normalizedItemKind == "Consumable"
		then buildConsumableData(grant)
		elseif normalizedItemKind == "InventoryItem"
			then buildInventoryItemData(grant)
			else cloneData(grant.Data)
	local displayText = resolveDropText(normalizedItemKind, resolvedData, grant.StackKey)
	local color = if normalizedItemKind == "Consumable"
		then Color3.fromRGB(114, 201, 133)
		elseif normalizedItemKind == "InventoryItem"
			then Color3.fromRGB(130, 184, 229)
		else Color3.fromRGB(226, 195, 104)
	local dropId = HttpService:GenerateGUID(false)
	local model = buildDropModel(dropId, position, displayText, quantity, color)
	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild("PickupPrompt")

	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			if ActiveDrops[dropId] == nil then
				return
			end

			getInventoryServiceServer().AddStackableItem(
				player,
				normalizedItemKind,
				grant.StackKey,
				resolvedData,
				quantity,
				grant.MaxStack,
				PICKED_UP_STORAGE_SECTION
			)
			removeDrop(dropId)
		end)
	end

	ActiveDrops[dropId] = {
		Id = dropId,
		Model = model,
	}
	return dropId
end

function ItemDropServiceServer.DropWeaponPath(position: Vector3, weaponPath: string): string?
	if type(weaponPath) ~= "string" or weaponPath == "" then
		return nil
	end

	local weaponPathParts = weaponPath:split(".")
	local displayText = weaponPathParts[#weaponPathParts]
	local dropId = HttpService:GenerateGUID(false)
	local model = buildDropModel(dropId, position, displayText, 1, Color3.fromRGB(201, 125, 84))
	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild("PickupPrompt")

	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			if ActiveDrops[dropId] == nil then
				return
			end

			getInventoryServiceServer().AddWeaponFromPath(player, weaponPath, PICKED_UP_STORAGE_SECTION)
			removeDrop(dropId)
		end)
	end

	ActiveDrops[dropId] = {
		Id = dropId,
		Model = model,
	}
	return dropId
end

function ItemDropServiceServer.init()
	ensureDropRoot()
end

return table.freeze(ItemDropServiceServer)
