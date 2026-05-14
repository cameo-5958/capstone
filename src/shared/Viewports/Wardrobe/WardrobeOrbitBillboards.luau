--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)
local ItemLoadoutServiceClient = require(ReplicatedStorage.Services.ItemLoadout.ItemLoadoutServiceClient)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local WardrobePreviewLoader = require(ReplicatedStorage.Viewports.Wardrobe.WardrobePreviewLoader)

local ORBIT_RADIUS = 4
local ORBIT_HEIGHT = 1.6
local ORBIT_SPEED = 0.2
local BILLBOARD_SIZE_PIXELS = 280
local SLOT_OFFSET = Vector3.new(-0.65, -0.45, 0)
local SLOT_NUMBER_BASE_TEXT_SIZE = 9
local NAME_BASE_TEXT_SIZE = 12
local WORLD_PREVIEW_SIZE_STUDS = 2.8
local WORLD_PREVIEW_CAMERA_BACKSET_STUDS = 0.08
local TEXT_BACKGROUND_COLOR = Color3.fromRGB(43, 28, 18)
local TEXT_BACKGROUND_TRANSPARENCY = 0.16
local TEXT_BAR_WIDTH_SCALE = 0.64

local FOREST_TEXT = Color3.fromRGB(239, 222, 190)
local FOREST_MUTED_TEXT = Color3.fromRGB(196, 162, 118)
local FOREST_ACCENT = Color3.fromRGB(223, 173, 91)
local FOREST_SHADOW = Color3.fromRGB(14, 8, 4)
local ORBIT_SLOT_LABELS = {
	"Weapon",
	"Armor",
	"Quick Item",
	"Quick Item",
}

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")

type LoadoutSlot = {
	Slot: number,
	ItemKind: string?,
	Name: string?,
	Class: string?,
	Type: string?,
	WeaponId: string?,
	BaseDamage: number?,
	GrantedStats: { [string]: number }?,
}

type LoadoutSnapshot = {
	Slots: { LoadoutSlot },
}

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

local function getTargetPosition(target: Model): Vector3
	local rootPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.Position
	end

	return target:GetPivot().Position
end

local function resolveWeaponModelTemplate(slot: LoadoutSlot?): Instance?
	if not slot then
		return nil
	end

	local weaponId = slot.WeaponId
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

local function cloneWeaponVisual(slot: LoadoutSlot?): Model?
	local template = resolveWeaponModelTemplate(slot)
	if not template then
		return nil
	end

	local clone = template:Clone()
	prepVisualClone(clone)

	if clone:IsA("Model") then
		return clone
	end

	local previewModel = Instance.new("Model")
	previewModel.Name = "WeaponPreview"

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

local function scaleModelToLargestAxis(model: Model, largestAxis: number): ()
	local _, size = model:GetBoundingBox()
	local largestCurrentAxis = math.max(size.X, size.Y, size.Z)
	if largestCurrentAxis <= 0 then
		return
	end

	pcall(function()
		model:ScaleTo(largestAxis / largestCurrentAxis)
	end)
end

local function positionWorldWeaponPreview(model: Model, position: Vector3): ()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local billboardPosition = position + SLOT_OFFSET
	local toCamera = camera.CFrame.Position - billboardPosition
	if toCamera.Magnitude <= 0.001 then
		toCamera = -camera.CFrame.LookVector
	else
		toCamera = toCamera.Unit
	end

	local visualPosition = billboardPosition - (toCamera * WORLD_PREVIEW_CAMERA_BACKSET_STUDS)
	local localX = (camera.CFrame.RightVector * 0.72 + camera.CFrame.UpVector * 0.42).Unit
	local localY = camera.CFrame.UpVector - (localX * camera.CFrame.UpVector:Dot(localX))
	if localY.Magnitude <= 0.001 then
		localY = camera.CFrame.UpVector
	else
		localY = localY.Unit
	end
	local localZ = localX:Cross(localY).Unit

	model:PivotTo(CFrame.fromMatrix(visualPosition, localX, localY, localZ))
end

local function frameWeaponModel(camera: Camera, model: Model): ()
	model:PivotTo(CFrame.Angles(0, math.rad(-35), math.rad(-12)))

	local boundingCFrame, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z, 1) * 0.5
	local focus = boundingCFrame.Position
	local fieldOfView = 32
	local distance = (radius / math.tan(math.rad(fieldOfView) * 0.5)) * 1.35
	local cameraPosition = focus + Vector3.new(radius * 0.65, radius * 0.15, distance)

	camera.CFrame = CFrame.lookAt(cameraPosition, focus)
	camera.FieldOfView = fieldOfView
end

local function WorldWeaponPreview(props: { Slot: LoadoutSlot?, Position: Vector3 })
	local folderRef = React.useRef(nil :: Folder?)
	local modelRef = React.useRef(nil :: Model?)
	local slot = props.Slot
	local slotIndex = if slot then slot.Slot else 0
	local weaponId = if slot and type(slot.WeaponId) == "string" then slot.WeaponId else ""

	React.useEffect(function()
		local folder = folderRef.current
		if not folder then
			return nil
		end
		local disposed = false

		if modelRef.current then
			modelRef.current:Destroy()
			modelRef.current = nil
		end

		local weaponModel = cloneWeaponVisual(slot)
		if weaponModel then
			weaponModel.Name = "WeaponWorldPreview"
			scaleModelToLargestAxis(weaponModel, WORLD_PREVIEW_SIZE_STUDS)
			task.spawn(function()
				WardrobePreviewLoader.PreloadInstanceAssets(weaponModel)

				if disposed or folderRef.current ~= folder then
					weaponModel:Destroy()
					return
				end

				weaponModel.Parent = folder
				modelRef.current = weaponModel
				positionWorldWeaponPreview(weaponModel, props.Position)
			end)
		end

		return function()
			disposed = true
			if modelRef.current then
				modelRef.current:Destroy()
				modelRef.current = nil
			elseif weaponModel and weaponModel.Parent == nil then
				weaponModel:Destroy()
			end
		end
	end, { slotIndex, weaponId })

	React.useEffect(function()
		local weaponModel = modelRef.current
		if weaponModel then
			positionWorldWeaponPreview(weaponModel, props.Position)
		end

		return nil
	end, { props.Position.X, props.Position.Y, props.Position.Z })

	return React.createElement("Folder", {
		Name = "WeaponWorldPreviewHost",
		ref = folderRef,
	})
end

local function WeaponSlotViewport(props: { Slot: LoadoutSlot? })
	local viewportRef = React.useRef(nil :: ViewportFrame?)
	local slot = props.Slot
	local slotIndex = if slot then slot.Slot else 0
	local weaponId = if slot and type(slot.WeaponId) == "string" then slot.WeaponId else ""

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

		local weaponModel = cloneWeaponVisual(slot)
		if weaponModel then
			task.spawn(function()
				WardrobePreviewLoader.PreloadInstanceAssets(weaponModel)

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
	end, { slotIndex, weaponId })

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

local function weaponSlot(slot: LoadoutSlot?, index: number)
	local hasWeapon = slot ~= nil and type(slot.WeaponId) == "string" and slot.WeaponId ~= ""
	local labelText = if slot and type(slot.Name) == "string" then slot.Name else "Empty"
	local slotLabel = ORBIT_SLOT_LABELS[index] or tostring(index)
	local slotNumberTextSize = SLOT_NUMBER_BASE_TEXT_SIZE
	local nameTextSize = NAME_BASE_TEXT_SIZE
	local barHeight = 22
	local slotNumberWidth = 56

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Size = UDim2.fromScale(1, 1),
	}, {
		Viewport = React.createElement(WeaponSlotViewport, {
			Slot = slot,
		}),
		TextBar = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = TEXT_BACKGROUND_COLOR,
			BackgroundTransparency = TEXT_BACKGROUND_TRANSPARENCY,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(TEXT_BAR_WIDTH_SCALE, 0, 0, barHeight),
			ZIndex = 3,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			SlotNumber = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				LayoutOrder = 1,
				Size = UDim2.new(0, slotNumberWidth, 1, 0),
				Text = slotLabel,
				TextColor3 = FOREST_ACCENT,
				TextSize = slotNumberTextSize,
				TextStrokeColor3 = FOREST_SHADOW,
				TextStrokeTransparency = 0.2,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 4,
			}),
			Name = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				LayoutOrder = 2,
				Size = UDim2.new(1, -slotNumberWidth - 8, 1, 0),
				Text = labelText,
				TextColor3 = if hasWeapon then FOREST_TEXT else FOREST_MUTED_TEXT,
				TextSize = nameTextSize,
				TextStrokeColor3 = FOREST_SHADOW,
				TextStrokeTransparency = 0.25,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 4,
			}),
		}),
	})
end

local function orbitSlot(slot: LoadoutSlot?, itemSlot: ItemLoadoutSlot?, index: number)
	if index <= 2 then
		return weaponSlot(slot, index)
	end

	local hasItem = itemSlot ~= nil and type(itemSlot.EntryId) == "string" and itemSlot.EntryId ~= ""
	local labelText = if itemSlot and type(itemSlot.Name) == "string" then itemSlot.Name else "Empty"
	local quantityText = if itemSlot
			and type(itemSlot.Quantity) == "number"
			and itemSlot.Quantity > 1
		then (" x%d"):format(itemSlot.Quantity)
		else ""
	local slotLabel = ORBIT_SLOT_LABELS[index] or tostring(index)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Size = UDim2.fromScale(1, 1),
	}, {
		TextBar = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = TEXT_BACKGROUND_COLOR,
			BackgroundTransparency = TEXT_BACKGROUND_TRANSPARENCY,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(TEXT_BAR_WIDTH_SCALE, 0, 0, 22),
			ZIndex = 3,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			SlotNumber = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				LayoutOrder = 1,
				Size = UDim2.new(0, 56, 1, 0),
				Text = slotLabel,
				TextColor3 = FOREST_ACCENT,
				TextSize = SLOT_NUMBER_BASE_TEXT_SIZE,
				TextStrokeColor3 = FOREST_SHADOW,
				TextStrokeTransparency = 0.2,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 4,
			}),
			Name = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				LayoutOrder = 2,
				Size = UDim2.new(1, -64, 1, 0),
				Text = labelText .. quantityText,
				TextColor3 = if hasItem then FOREST_TEXT else FOREST_MUTED_TEXT,
				TextSize = NAME_BASE_TEXT_SIZE,
				TextStrokeColor3 = FOREST_SHADOW,
				TextStrokeTransparency = 0.25,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 4,
			}),
		}),
	})
end

local function WardrobeOrbitBillboards(props: { Target: Model })
	local angle, setAngle = React.useState(0)
	local loadout, setLoadout = React.useState(function()
		return WeaponServiceClient.GetLoadoutData() :: LoadoutSnapshot
	end)
	local itemLoadout, setItemLoadout = React.useState(function()
		return ItemLoadoutServiceClient.GetLoadoutData() :: ItemLoadoutSnapshot
	end)

	React.useEffect(function()
		local startedAt = os.clock()
		local connection = RunService.RenderStepped:Connect(function()
			setAngle((os.clock() - startedAt) * ORBIT_SPEED)
		end)

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
		local connection = ItemLoadoutServiceClient.GetLoadoutChangedSignal()
			:Connect(function(nextLoadout: ItemLoadoutSnapshot)
				setItemLoadout(nextLoadout)
			end)

		ItemLoadoutServiceClient.RequestLoadout()
		setItemLoadout(ItemLoadoutServiceClient.GetLoadoutData() :: ItemLoadoutSnapshot)

		return function()
			connection:Disconnect()
		end
	end, {})

	local center = getTargetPosition(props.Target)
	local children = {}

	for index = 1, 4 do
		local theta = angle + ((index - 1) * math.pi * 0.5)
		local position = center
			+ Vector3.new(math.cos(theta) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(theta) * ORBIT_RADIUS)
		local slot = loadout.Slots[index]
		local itemSlot = if index >= 3 then itemLoadout.Slots[index - 2] else nil

		children["OrbitAnchor" .. index] = React.createElement("Part", {
			Name = "WardrobeOrbitAnchor" .. index,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(position),
			Size = Vector3.new(0.2, 0.2, 0.2),
			Transparency = 1,
		}, {
			WeaponPreview = React.createElement(WorldWeaponPreview, {
				Position = position,
				Slot = slot,
			}),
			Billboard = React.createElement("BillboardGui", {
				AlwaysOnTop = false,
				LightInfluence = 0,
				MaxDistance = 200,
				Size = UDim2.fromOffset(BILLBOARD_SIZE_PIXELS, BILLBOARD_SIZE_PIXELS),
				StudsOffsetWorldSpace = SLOT_OFFSET,
			}, {
				Slot = orbitSlot(slot, itemSlot, index),
			}),
		})
	end

	return React.createElement(React.Fragment, nil, children)
end

return WardrobeOrbitBillboards
