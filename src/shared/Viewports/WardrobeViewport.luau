--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlayerConfig = require(ReplicatedStorage.Database.Players.Default.Data)
local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)
local SerializedViewCamera = require(ReplicatedStorage.Viewports.Forest.Viewpoints.ViewCamera)
local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local InventoryServiceClient = require(ReplicatedStorage.Services.Inventory.InventoryServiceClient)
local ItemLoadoutServiceClient = require(ReplicatedStorage.Services.ItemLoadout.ItemLoadoutServiceClient)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local WorldServiceClient = require(ReplicatedStorage.Services.World.WorldServiceClient)
local ShopServiceClient = require(ReplicatedStorage.Services.Shop.ShopServiceClient)
local WardrobeInventoryPanel = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeInventoryPanel)
local WardrobeOrbitBillboards = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeOrbitBillboards)
local WardrobePreviewLoader = require(ReplicatedStorage.Viewports.Wardrobe.WardrobePreviewLoader)
local WardrobeCraftingPanel = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeCraftingPanel)
local WardrobeReadyPanel = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeReadyPanel)
local WardrobeSelection = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeSelection)
local WardrobeStatsPanel = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeStatsPanel)

local WardrobeViewport = {}

local VIEWPORTS_FOLDER_NAME = "Viewports"
local WARDROBE_FOLDER_NAME = "Wardrobe"
local FOREST_FOLDER_NAME = "Forest"
local TAVERN_SET_NAME = "TavernSet"
local VIEW_CAMERA_NAME = "ViewCamera"
local PLAYER_POINT_NAME = "PlayerPoint"
local PLAYER_SLOT_ONE_POINT_NAME = "PlayerPoint1"
local PREVIEW_CHARACTER_NAME = "PreviewCharacter"
local ORBIT_BILLBOARDS_FOLDER_NAME = "WardrobeOrbitBillboards"
local WARDROBE_GUI_NAME = "WardrobeGui"
local CAMERA_BIND_NAME = "WardrobeViewCamera"
local PLAYER_LIGHT_NAME = "PlayerVisionLight"
local FAR_AWAY_CFRAME = CFrame.new(0, 5000, 0)
local NORMAL_UI_GUI_NAMES = {
	"PlayerUI",
}

local mountedTavernSet: Model? = nil
local previewCharacter: Model? = nil
local secondaryPreviewCharacters: { Model } = {}
local previewIdleTrack: AnimationTrack? = nil
local orbitBillboardsRoot: any? = nil
local orbitBillboardsContainer: Folder? = nil
local wardrobeGuiRoot: any? = nil
local wardrobeGui: ScreenGui? = nil
local startStateConnection: RBXScriptConnection? = nil
local isVisible = false
local previousCurrentCamera: Camera? = nil
local previousCameraType: Enum.CameraType? = nil
local previousCameraSubject: Instance? = nil
local previousCameraCFrame: CFrame? = nil
local previousCameraFocus: CFrame? = nil
local previousCameraFieldOfView: number? = nil
local activeViewCameraCFrame: CFrame? = nil
local activeViewCameraFocus: CFrame? = nil
local activeViewCameraFieldOfView: number? = nil
local hiddenGuiStates: { [string]: boolean } = {}
local visibleSessionId = 0
local interfaceReadySignal = Signal.new()
local isInterfaceReady = false
local WARDROBE_PREVIEW_SYNC_TIMEOUT = 5
local PLAYER_SLOT_MARKER_NAMES = {
	"Person1",
	"Person2",
	"Person3",
	"Person4",
	"PlayerPoint1",
	"PlayerPoint2",
	"PlayerPoint3",
	"PlayerPoint4",
	"PlayerSlot1",
	"PlayerSlot2",
	"PlayerSlot3",
	"PlayerSlot4",
}
local TEMP_FILL_OTHER_PLAYER_SLOTS_WITH_LOCAL_PREVIEW = true
local LEFT_PANEL_WIDTH = 500
local LEFT_PANEL_HEIGHT = 420
local LEFT_PANEL_LEFT_MARGIN = 24
local LEFT_PANEL_CENTER_Y_OFFSET = 0
local WARDROBE_NAV_Y_OFFSET = 222
local WARDROBE_NAV_BUTTON_WIDTH = 158
local WARDROBE_NAV_BUTTON_HEIGHT = 38
local WARDROBE_NAV_GAP = 12
local NAV_WOOD = Color3.fromRGB(46, 31, 18)
local NAV_WOOD_ACTIVE = Color3.fromRGB(84, 55, 26)
local NAV_STROKE = Color3.fromRGB(160, 118, 66)
local NAV_TEXT = Color3.fromRGB(241, 226, 194)
local NAV_TEXT_MUTED = Color3.fromRGB(148, 129, 104)

type WardrobePage = "Inventory" | "Crafting"
type ShopCatalog = ShopServiceClient.ShopCatalog

local function hasInitialWardrobeData(): boolean
	return InventoryServiceClient.HasReceivedInitialInventory()
		and WeaponServiceClient.HasReceivedInitialLoadout()
		and ItemLoadoutServiceClient.HasReceivedInitialLoadout()
end

local function setInterfaceReady(nextValue: boolean): ()
	if isInterfaceReady == nextValue then
		return
	end

	isInterfaceReady = nextValue
	interfaceReadySignal:Fire(isInterfaceReady)
end

local function waitForInitialWardrobeData(timeoutSeconds: number): boolean
	local deadline = os.clock() + timeoutSeconds

	InventoryServiceClient.RequestInventory()
	WeaponServiceClient.RequestLoadout()
	ItemLoadoutServiceClient.RequestLoadout()

	while os.clock() < deadline do
		if hasInitialWardrobeData() then
			return true
		end

		RunService.Heartbeat:Wait()
	end

	return hasInitialWardrobeData()
end

local function warmWardrobePreviews(): ()
	waitForInitialWardrobeData(WARDROBE_PREVIEW_SYNC_TIMEOUT)
	WardrobePreviewLoader.WarmupWardrobeAssets(
		InventoryServiceClient.GetInventory(),
		WeaponServiceClient.GetLoadoutData(),
		ItemLoadoutServiceClient.GetLoadoutData()
	)
end

local function setPlayerVisionLightEnabled(isEnabled: boolean): ()
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local light = rootPart:FindFirstChild(PLAYER_LIGHT_NAME)
	if light and light:IsA("PointLight") then
		light.Enabled = isEnabled
	end
end

local function getWardrobeFolder(): Instance?
	local viewportFolder = ReplicatedStorage:FindFirstChild("Viewports")
		or ReplicatedStorage:WaitForChild("Viewports", 5)
	if not viewportFolder then
		warn("WardrobeViewport: ReplicatedStorage.Viewports was not found.")
		return nil
	end

	local wardrobeFolder = viewportFolder:FindFirstChild("Wardrobe") or viewportFolder:WaitForChild("Wardrobe", 5)
	if not wardrobeFolder then
		warn("WardrobeViewport: ReplicatedStorage.Viewports.Wardrobe was not found.")
		return nil
	end

	return wardrobeFolder
end

local function getForestFolder(): Instance?
	local viewportFolder = ReplicatedStorage:FindFirstChild("Viewports")
		or ReplicatedStorage:WaitForChild("Viewports", 5)
	if not viewportFolder then
		warn("WardrobeViewport: ReplicatedStorage.Viewports was not found.")
		return nil
	end

	local forestFolder = viewportFolder:FindFirstChild(FOREST_FOLDER_NAME)
		or viewportFolder:WaitForChild(FOREST_FOLDER_NAME, 5)
	if not forestFolder then
		return nil
	end

	return forestFolder
end

local function getViewportsRoot(): Instance?
	local viewportFolder = ReplicatedStorage:FindFirstChild("Viewports")
		or ReplicatedStorage:WaitForChild("Viewports", 5)
	if not viewportFolder then
		warn("WardrobeViewport: ReplicatedStorage.Viewports was not found.")
		return nil
	end

	return viewportFolder
end

local function getOrCreateRuntimeWardrobeFolder(): Folder
	local viewportsFolder = Workspace:FindFirstChild(VIEWPORTS_FOLDER_NAME)
	if not viewportsFolder or not viewportsFolder:IsA("Folder") then
		viewportsFolder = Instance.new("Folder")
		viewportsFolder.Name = VIEWPORTS_FOLDER_NAME
		viewportsFolder.Parent = Workspace
	end

	local wardrobeFolder = viewportsFolder:FindFirstChild(WARDROBE_FOLDER_NAME)
	if not wardrobeFolder or not wardrobeFolder:IsA("Folder") then
		wardrobeFolder = Instance.new("Folder")
		wardrobeFolder.Name = WARDROBE_FOLDER_NAME
		wardrobeFolder.Parent = viewportsFolder
	end

	return wardrobeFolder
end

local function getTavernSetTemplate(): Model?
	local forestFolder = getForestFolder()
	if forestFolder then
		local forestNamedTemplate = forestFolder:FindFirstChild(TAVERN_SET_NAME)
		if forestNamedTemplate and forestNamedTemplate:IsA("Model") then
			return forestNamedTemplate
		end

		local forestViewportTemplate = forestFolder:FindFirstChild("Viewport")
		if forestViewportTemplate and forestViewportTemplate:IsA("Model") then
			return forestViewportTemplate
		end

		for _, child in ipairs(forestFolder:GetChildren()) do
			if child:IsA("Model") then
				return child
			end
		end
	end

	local viewportsRoot = getViewportsRoot()
	if viewportsRoot then
		local rootNamedTemplate = viewportsRoot:FindFirstChild(TAVERN_SET_NAME)
		if rootNamedTemplate and rootNamedTemplate:IsA("Model") then
			return rootNamedTemplate
		end

		local rootViewportTemplate = viewportsRoot:FindFirstChild("Viewport")
		if rootViewportTemplate and rootViewportTemplate:IsA("Model") then
			return rootViewportTemplate
		end

		for _, child in ipairs(viewportsRoot:GetChildren()) do
			if child:IsA("Model") then
				return child
			end
		end
	end

	local wardrobeFolder = getWardrobeFolder()
	if not wardrobeFolder then
		return nil
	end

	local namedTemplate = wardrobeFolder:FindFirstChild(TAVERN_SET_NAME)
	if namedTemplate and namedTemplate:IsA("Model") then
		return namedTemplate
	end

	local viewportTemplate = wardrobeFolder:FindFirstChild("Viewport")
	if viewportTemplate and viewportTemplate:IsA("Model") then
		return viewportTemplate
	end

	return wardrobeFolder:FindFirstChildOfClass("Model")
end

local function findViewCamera(tavernSet: Model): Camera?
	local viewCamera = tavernSet:FindFirstChild(VIEW_CAMERA_NAME, true)
	if viewCamera and viewCamera:IsA("Camera") then
		return viewCamera
	end

	return nil
end

local function ensureViewCamera(tavernSet: Model): Camera
	local viewCamera = findViewCamera(tavernSet)
	if viewCamera then
		SerializedViewCamera.ApplyTo(viewCamera)
		return viewCamera
	end

	viewCamera = SerializedViewCamera.Create()
	viewCamera.Parent = tavernSet

	return viewCamera
end

local function findPlayerPointByNames(tavernSet: Model, names: { string }): BasePart?
	for _, name in ipairs(names) do
		local playerPoint = tavernSet:FindFirstChild(name, true)
		if playerPoint and playerPoint:IsA("BasePart") then
			return playerPoint
		end
	end

	return nil
end

local function findPlayerPoint(tavernSet: Model): BasePart?
	local playerPoint = findPlayerPointByNames(tavernSet, {
		PLAYER_SLOT_ONE_POINT_NAME,
		"PlayerPoint01",
		"PlayerPoint_1",
		"PlayerSlot1",
		"PlayerSlot01",
		"PlayerPosition1",
		"Pos1",
		PLAYER_POINT_NAME,
	})
	if playerPoint and playerPoint:IsA("BasePart") then
		return playerPoint
	end

	return nil
end

local function clearPlayerSlotMarkers(tavernSet: Model): ()
	for _, markerName in ipairs(PLAYER_SLOT_MARKER_NAMES) do
		local marker = tavernSet:FindFirstChild(markerName, true)
		if marker and marker:IsA("BasePart") then
			marker:Destroy()
		end
	end
end

local function findOtherPlayerPoints(tavernSet: Model): { CFrame }
	local points = {} :: { CFrame }
	for slot = 2, 4 do
		local point = findPlayerPointByNames(tavernSet, {
			"PlayerPoint" .. tostring(slot),
			string.format("PlayerPoint0%d", slot),
			"PlayerPoint_" .. tostring(slot),
			"PlayerSlot" .. tostring(slot),
			string.format("PlayerSlot0%d", slot),
			"PlayerPosition" .. tostring(slot),
			"Pos" .. tostring(slot),
			"Person" .. tostring(slot),
		})
		if point then
			table.insert(points, point.CFrame)
		end
	end
	return points
end

local function clearSecondaryPreviewCharacters(): ()
	for _, character in ipairs(secondaryPreviewCharacters) do
		if character.Parent then
			character:Destroy()
		end
	end
	table.clear(secondaryPreviewCharacters)
end

local function spawnSecondaryPreviewCharacters(tavernSet: Model, sourcePreview: Model, points: { CFrame }): ()
	clearSecondaryPreviewCharacters()
	for index, pointCFrame in ipairs(points) do
		local clone = sourcePreview:Clone()
		clone.Name = string.format("PreviewCharacter%d", index + 1)
		clone.Parent = tavernSet
		clone:PivotTo(pointCFrame)
		table.insert(secondaryPreviewCharacters, clone)
	end
end

local function prepPreviewCharacter(character: Model): ()
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = true
	end
end

local function playSwordIdle(character: Model): ()
	if previewIdleTrack then
		previewIdleTrack:Stop()
		previewIdleTrack:Destroy()
		previewIdleTrack = nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local animationId = PlayerConfig.__Animations and PlayerConfig.__Animations.Idle
	if type(animationId) ~= "string" or animationId == "" then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	previewIdleTrack = animator:LoadAnimation(animation)
	previewIdleTrack.Looped = true
	previewIdleTrack:Play()
	animation:Destroy()
end

local function unmountOrbitBillboards(): ()
	if orbitBillboardsRoot then
		orbitBillboardsRoot:unmount()
		orbitBillboardsRoot = nil
	end

	if orbitBillboardsContainer then
		orbitBillboardsContainer:Destroy()
		orbitBillboardsContainer = nil
	end
end

local function mountOrbitBillboards(tavernSet: Model, target: Model): ()
	if orbitBillboardsRoot and orbitBillboardsContainer and orbitBillboardsContainer.Parent == tavernSet then
		orbitBillboardsRoot:render(React.createElement(WardrobeOrbitBillboards, {
			Target = target,
		}))
		return
	end

	unmountOrbitBillboards()

	local container = Instance.new("Folder")
	container.Name = ORBIT_BILLBOARDS_FOLDER_NAME
	container.Parent = tavernSet

	local root = ReactRoblox.createRoot(container)
	root:render(React.createElement(WardrobeOrbitBillboards, {
		Target = target,
	}))

	orbitBillboardsContainer = container
	orbitBillboardsRoot = root
end

local function unmountWardrobeGui(): ()
	setInterfaceReady(false)

	if wardrobeGui then
		wardrobeGui.Enabled = false
	end

	if wardrobeGuiRoot then
		wardrobeGuiRoot:unmount()
		wardrobeGuiRoot = nil
	end

	if wardrobeGui then
		wardrobeGui:Destroy()
		wardrobeGui = nil
	end
end

local function setNormalHudVisible(isEnabled: boolean): ()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	for _, guiName in ipairs(NORMAL_UI_GUI_NAMES) do
		local screenGui = playerGui:FindFirstChild(guiName)
		if not screenGui or not screenGui:IsA("ScreenGui") then
			continue
		end

		if isEnabled then
			local previousState = hiddenGuiStates[guiName]
			if previousState ~= nil then
				screenGui.Enabled = previousState
			end
		else
			if hiddenGuiStates[guiName] == nil then
				hiddenGuiStates[guiName] = screenGui.Enabled
			end
			screenGui.Enabled = false
		end
	end

	if isEnabled then
		table.clear(hiddenGuiStates)
	end
end

local function renderWardrobeGui()
	local function WardrobeRoot()
		local activePage, setActivePage = React.useState("Inventory" :: WardrobePage)
		local shopCatalog, setShopCatalog = React.useState(function()
			return ShopServiceClient.GetCatalog() :: ShopCatalog
		end)
		local isLocked = WorldServiceClient.IsWardrobeReady() and not WorldServiceClient.IsMatchStarted()

		local function iconButton(
			layoutOrder: number,
			labelText: string,
			isActive: boolean,
			isEnabled: boolean,
			iconFactory: () -> any,
			onActivated: (() -> ())?
		)
			return React.createElement("TextButton", {
				Active = isEnabled,
				AutoButtonColor = isEnabled,
				BackgroundColor3 = if isActive then NAV_WOOD_ACTIVE else NAV_WOOD,
				BackgroundTransparency = if isEnabled then 0.06 else 0.26,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				LayoutOrder = layoutOrder,
				Selectable = isEnabled,
				Size = UDim2.fromOffset(WARDROBE_NAV_BUTTON_WIDTH, WARDROBE_NAV_BUTTON_HEIGHT),
				Text = "",
				ZIndex = 40,
				[React.Event.Activated] = function()
					if isEnabled and onActivated then
						onActivated()
					end
				end,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 10),
				}),
				Stroke = React.createElement("UIStroke", {
					Color = NAV_STROKE,
					Thickness = if isActive then 2 else 1,
					Transparency = if isEnabled then 0.14 else 0.55,
				}),
				Icon = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(24, WARDROBE_NAV_BUTTON_HEIGHT * 0.5),
					Size = UDim2.fromOffset(26, 26),
					ZIndex = 41,
				}, iconFactory()),
				Label = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(48, 0),
					Size = UDim2.new(1, -56, 1, 0),
					Text = labelText,
					TextColor3 = if isEnabled then NAV_TEXT else NAV_TEXT_MUTED,
					TextSize = 14,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 41,
				}),
			})
		end

		local function inventoryIcon()
			return {
				TopLeft = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromOffset(9, 9),
					ZIndex = 42,
				}),
				TopRight = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(13, 0),
					Size = UDim2.fromOffset(9, 9),
					ZIndex = 42,
				}),
				BottomLeft = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(0, 13),
					Size = UDim2.fromOffset(9, 9),
					ZIndex = 42,
				}),
				BottomRight = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(13, 13),
					Size = UDim2.fromOffset(9, 9),
					ZIndex = 42,
				}),
			}
		end

		local function craftingIcon()
			return {
				Handle = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = NAV_TEXT,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(7, 18),
					Rotation = -40,
					Size = UDim2.fromOffset(5, 18),
					ZIndex = 42,
				}),
				Head = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = NAV_TEXT,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(16, 8),
					Rotation = -40,
					Size = UDim2.fromOffset(16, 7),
					ZIndex = 42,
				}),
				Block = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(15, 15),
					Size = UDim2.fromOffset(8, 8),
					ZIndex = 42,
				}),
			}
		end

		local function resultsIcon()
			return {
				Base = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT_MUTED,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(2, 18),
					Size = UDim2.fromOffset(20, 4),
					ZIndex = 42,
				}),
				BarOne = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT_MUTED,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(3, 10),
					Size = UDim2.fromOffset(4, 8),
					ZIndex = 42,
				}),
				BarTwo = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT_MUTED,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(10, 6),
					Size = UDim2.fromOffset(4, 12),
					ZIndex = 42,
				}),
				BarThree = React.createElement("Frame", {
					BackgroundColor3 = NAV_TEXT_MUTED,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(17, 2),
					Size = UDim2.fromOffset(4, 16),
					ZIndex = 42,
				}),
			}
		end

		React.useEffect(function()
			local catalogConnection = ShopServiceClient.GetCatalogChangedSignal():Connect(function(nextCatalog: ShopCatalog)
				setShopCatalog(nextCatalog)
			end)
			ShopServiceClient.RequestCatalog()
			setShopCatalog(ShopServiceClient.GetCatalog() :: ShopCatalog)

			return function()
				catalogConnection:Disconnect()
			end
		end, {})

		return React.createElement(React.Fragment, nil, {
			Stats = if activePage == "Inventory" then React.createElement(WardrobeStatsPanel, {
				IsLocked = isLocked,
			}) else nil,
			Inventory = React.createElement(WardrobeInventoryPanel, {
				IsLocked = isLocked,
			}),
			Crafting = if activePage == "Crafting" then React.createElement(WardrobeCraftingPanel, {
				Catalog = shopCatalog,
			}) else nil,
			Navigation = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.new(0, LEFT_PANEL_LEFT_MARGIN, 0.5, WARDROBE_NAV_Y_OFFSET),
				Size = UDim2.fromOffset(
					(WARDROBE_NAV_BUTTON_WIDTH * 3) + (WARDROBE_NAV_GAP * 2),
					WARDROBE_NAV_BUTTON_HEIGHT
				),
				ZIndex = 39,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, WARDROBE_NAV_GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				InventoryButton = iconButton(1, "Items", activePage == "Inventory", true, inventoryIcon, function()
					setActivePage("Inventory")
				end),
				CraftingButton = iconButton(2, "Craft", activePage == "Crafting", true, craftingIcon, function()
					setActivePage("Crafting")
				end),
				ResultsButton = iconButton(3, "Results", false, false, resultsIcon, nil),
			}),
			Ready = React.createElement(WardrobeReadyPanel, {
				IsLocked = isLocked,
			}),
		})
	end

	return React.createElement(WardrobeRoot)
end

local function mountWardrobeGui(): ()
	if wardrobeGuiRoot then
		if wardrobeGui then
			wardrobeGui.Enabled = true
		end
		wardrobeGuiRoot:render(renderWardrobeGui())
		setInterfaceReady(true)
		return
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = WARDROBE_GUI_NAME
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 45
	screenGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(renderWardrobeGui())

	wardrobeGui = screenGui
	wardrobeGuiRoot = root
	setInterfaceReady(true)
end

local function mountPreviewCharacter(tavernSet: Model): ()
	local playerPoint = findPlayerPoint(tavernSet)
	if not playerPoint then
		return
	end
	local playerPointCFrame = playerPoint.CFrame
	local otherPlayerPointCFrames = findOtherPlayerPoints(tavernSet)
	clearPlayerSlotMarkers(tavernSet)

	local preview = previewCharacter
	while not preview do
		local character = Players.LocalPlayer.Character
		if character then
			local wasArchivable = character.Archivable
			character.Archivable = true
			preview = character:Clone()
			character.Archivable = wasArchivable
			if preview then
				preview.Name = PREVIEW_CHARACTER_NAME
				prepPreviewCharacter(preview)
				previewCharacter = preview
			end
		end

		task.wait()
	end

	local previousPreview = tavernSet:FindFirstChild(PREVIEW_CHARACTER_NAME)
	if previousPreview and previousPreview ~= preview then
		previousPreview:Destroy()
	end

	preview.Parent = tavernSet
	preview:PivotTo(playerPointCFrame)
	playSwordIdle(preview)
	if TEMP_FILL_OTHER_PLAYER_SLOTS_WITH_LOCAL_PREVIEW then
		spawnSecondaryPreviewCharacters(tavernSet, preview, otherPlayerPointCFrames)
	end
	mountOrbitBillboards(tavernSet, preview)
end

local function createPreviewCharacter(character: Model): ()
	if previewIdleTrack then
		previewIdleTrack:Stop()
		previewIdleTrack:Destroy()
		previewIdleTrack = nil
	end
	if previewCharacter then
		unmountOrbitBillboards()
		clearSecondaryPreviewCharacters()
		previewCharacter:Destroy()
		previewCharacter = nil
	end

	local wasArchivable = character.Archivable
	character.Archivable = true
	local preview = character:Clone()
	character.Archivable = wasArchivable
	if not preview then
		return
	end

	preview.Name = PREVIEW_CHARACTER_NAME
	prepPreviewCharacter(preview)
	previewCharacter = preview

	if mountedTavernSet and mountedTavernSet.Parent then
		mountPreviewCharacter(mountedTavernSet)
	end
end

local function pivotTavernSet(tavernSet: Model, targetCFrame: CFrame): ()
	local sourceCFrame = tavernSet:GetPivot()
	local viewCamera = findViewCamera(tavernSet)
	local viewCameraOffset = viewCamera and sourceCFrame:ToObjectSpace(viewCamera.CFrame) or nil
	local viewCameraFocusOffset = viewCamera and sourceCFrame:ToObjectSpace(viewCamera.Focus) or nil

	tavernSet:PivotTo(targetCFrame)

	if viewCamera and viewCameraOffset and viewCameraFocusOffset then
		viewCamera.CFrame = targetCFrame * viewCameraOffset
		viewCamera.Focus = targetCFrame * viewCameraFocusOffset
	end
end

local function destroyRuntimeTavernSet(tavernSet: Instance): ()
	if orbitBillboardsContainer and orbitBillboardsContainer:IsDescendantOf(tavernSet) then
		unmountOrbitBillboards()
	end

	clearSecondaryPreviewCharacters()

	if previewCharacter and previewCharacter.Parent == tavernSet then
		previewCharacter.Parent = nil
	end

	if mountedTavernSet == tavernSet then
		mountedTavernSet = nil
	end

	tavernSet:Destroy()
end

local function ensureTavernSet(): Model?
	local runtimeFolder = getOrCreateRuntimeWardrobeFolder()
	local existingTavernSet = runtimeFolder:FindFirstChild(TAVERN_SET_NAME)
	if existingTavernSet then
		destroyRuntimeTavernSet(existingTavernSet)
	end

	local template = getTavernSetTemplate()
	if not template then
		return nil
	end

	local tavernSet = template:Clone()
	tavernSet.Name = TAVERN_SET_NAME
	ensureViewCamera(tavernSet)
	pivotTavernSet(tavernSet, FAR_AWAY_CFRAME)
	tavernSet.Parent = runtimeFolder

	mountedTavernSet = tavernSet
	mountPreviewCharacter(tavernSet)

	return tavernSet
end

local function rememberCurrentCamera(camera: Camera): ()
	if previousCurrentCamera then
		return
	end

	previousCurrentCamera = camera
	if previousCameraType then
		return
	end

	previousCameraType = camera.CameraType
	previousCameraSubject = camera.CameraSubject
	previousCameraCFrame = camera.CFrame
	previousCameraFocus = camera.Focus
	previousCameraFieldOfView = camera.FieldOfView
end

local function applyViewCamera(viewCamera: Camera, cameraCFrame: CFrame, cameraFocus: CFrame, fieldOfView: number): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	rememberCurrentCamera(camera)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CameraSubject = nil
	camera.CFrame = cameraCFrame
	camera.Focus = cameraFocus
	camera.FieldOfView = fieldOfView
end

local function bindViewCamera(tavernSet: Model): boolean
	local viewCamera = findViewCamera(tavernSet)
	if not viewCamera then
		warn("WardrobeViewport: ViewCamera was not found on the runtime tavern set.")
		return false
	end

	activeViewCameraCFrame = viewCamera.CFrame
	activeViewCameraFocus = viewCamera.Focus
	activeViewCameraFieldOfView = viewCamera.FieldOfView
	applyViewCamera(viewCamera, activeViewCameraCFrame, activeViewCameraFocus, activeViewCameraFieldOfView)
	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, function()
		if not isVisible or not mountedTavernSet or not mountedTavernSet.Parent then
			return
		end

		local activeViewCamera = findViewCamera(mountedTavernSet)
		if activeViewCamera then
			applyViewCamera(
				activeViewCamera,
				activeViewCamera.CFrame,
				activeViewCamera.Focus,
				activeViewCamera.FieldOfView
			)
		end
	end)

	return true
end

local function restoreCamera(): ()
	RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)

	local camera = Workspace.CurrentCamera
	local restoreTarget = previousCurrentCamera or camera
	if restoreTarget and previousCameraType then
		if Workspace.CurrentCamera ~= restoreTarget then
			Workspace.CurrentCamera = restoreTarget
		end
		restoreTarget.CameraType = previousCameraType
		restoreTarget.CameraSubject = previousCameraSubject
		if previousCameraCFrame then
			restoreTarget.CFrame = previousCameraCFrame
		end
		if previousCameraFocus then
			restoreTarget.Focus = previousCameraFocus
		end
		if previousCameraFieldOfView then
			restoreTarget.FieldOfView = previousCameraFieldOfView
		end
	end

	previousCurrentCamera = nil
	previousCameraType = nil
	previousCameraSubject = nil
	previousCameraCFrame = nil
	previousCameraFocus = nil
	previousCameraFieldOfView = nil
	activeViewCameraCFrame = nil
	activeViewCameraFocus = nil
	activeViewCameraFieldOfView = nil
end

function WardrobeViewport.Show(): boolean
	visibleSessionId += 1
	local sessionId = visibleSessionId
	isVisible = true
	setInterfaceReady(false)
	WardrobeSelection.SetSelectedItem(nil)

	task.spawn(function()
		warmWardrobePreviews()

		if not isVisible or visibleSessionId ~= sessionId then
			return
		end

		local tavernSet = ensureTavernSet()
		if not tavernSet then
			if visibleSessionId == sessionId then
				isVisible = false
				setInterfaceReady(false)
			end
			return
		end

		local didBindCamera = bindViewCamera(tavernSet)
		if didBindCamera then
			setPlayerVisionLightEnabled(false)
			setNormalHudVisible(false)
			mountWardrobeGui()
		elseif visibleSessionId == sessionId then
			isVisible = false
			setInterfaceReady(false)
		end
	end)

	return true
end

function WardrobeViewport.Hide(): ()
	visibleSessionId += 1
	isVisible = false
	setInterfaceReady(false)
	WardrobeSelection.SetSelectedItem(nil)
	setPlayerVisionLightEnabled(true)
	unmountWardrobeGui()
	setNormalHudVisible(true)
	clearSecondaryPreviewCharacters()
	restoreCamera()
end

function WardrobeViewport.IsVisible(): boolean
	return isVisible
end

function WardrobeViewport.IsInterfaceReady(): boolean
	return isInterfaceReady
end

function WardrobeViewport.GetInterfaceReadyChangedSignal()
	return interfaceReadySignal
end

local function createPreviewFromCurrentCharacter(): ()
	local character = Players.LocalPlayer.Character
	if character then
		createPreviewCharacter(character)
	end
end

Players.LocalPlayer.CharacterAdded:Connect(function()
	task.defer(createPreviewFromCurrentCharacter)
	if isVisible then
		task.defer(setPlayerVisionLightEnabled, false)
	end
end)
Players.LocalPlayer.CharacterAppearanceLoaded:Connect(createPreviewCharacter)
if Players.LocalPlayer.Character then
	task.defer(createPreviewFromCurrentCharacter)
	if Players.LocalPlayer:HasAppearanceLoaded() then
		task.defer(createPreviewCharacter, Players.LocalPlayer.Character)
	end
end

ensureTavernSet()

startStateConnection = WorldServiceClient.GetStartStateChangedSignal():Connect(function()
	if wardrobeGuiRoot then
		wardrobeGuiRoot:render(renderWardrobeGui())
	end
end)

return table.freeze(WardrobeViewport)
