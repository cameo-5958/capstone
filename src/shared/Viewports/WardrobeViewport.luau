--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlayerConfig = require(ReplicatedStorage.Database.Players.Default.Data)
local SerializedViewCamera = require(ReplicatedStorage.Viewports.Wardrobe.Viewpoints.ViewCamera)
local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local BorderedTextBox = require(ReplicatedStorage.Classes.UI.BorderedTextBox)
local WardrobeInventoryPanel = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeInventoryPanel)
local WardrobeOrbitBillboards = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeOrbitBillboards)
local WardrobeSelection = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeSelection)
local WardrobeStatsPanel = require(ReplicatedStorage.Viewports.Wardrobe.WardrobeStatsPanel)

local WardrobeViewport = {}

local VIEWPORTS_FOLDER_NAME = "Viewports"
local WARDROBE_FOLDER_NAME = "Wardrobe"
local TAVERN_SET_NAME = "TavernSet"
local VIEW_CAMERA_NAME = "ViewCamera"
local PLAYER_POINT_NAME = "PlayerPoint"
local PREVIEW_CHARACTER_NAME = "PreviewCharacter"
local ORBIT_BILLBOARDS_FOLDER_NAME = "WardrobeOrbitBillboards"
local WARDROBE_GUI_NAME = "WardrobeGui"
local CAMERA_BIND_NAME = "WardrobeViewCamera"
local FAR_AWAY_CFRAME = CFrame.new(0, 5000, 0)
local NORMAL_UI_GUI_NAMES = {
	"PlayerUI",
	"PlayerStatsHud",
}

local mountedTavernSet: Model? = nil
local previewCharacter: Model? = nil
local previewIdleTrack: AnimationTrack? = nil
local orbitBillboardsRoot: any? = nil
local orbitBillboardsContainer: Folder? = nil
local wardrobeGuiRoot: any? = nil
local wardrobeGui: ScreenGui? = nil
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

local function getWardrobeFolder(): Instance?
	local viewportFolder = ReplicatedStorage:FindFirstChild("Viewports") or ReplicatedStorage:WaitForChild("Viewports", 5)
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

local function findPlayerPoint(tavernSet: Model): BasePart?
	local playerPoint = tavernSet:FindFirstChild(PLAYER_POINT_NAME, true)
	if playerPoint and playerPoint:IsA("BasePart") then
		return playerPoint
	end

	return nil
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
	return React.createElement(React.Fragment, nil, {
		Stats = React.createElement(WardrobeStatsPanel),
		Inventory = React.createElement(WardrobeInventoryPanel),
		BorderTextBoxTest = React.createElement(BorderedTextBox.Component, {
			AnchorPoint = Vector2.new(0.5, 1),
			BorderThickness = 14,
			PlaceholderText = "Border test",
			Position = UDim2.new(0.5, 0, 1, -34),
			Size = UDim2.fromOffset(220, 54),
			ZIndex = 30,
		}),
	})
end

local function mountWardrobeGui(): ()
	if wardrobeGuiRoot then
		wardrobeGuiRoot:render(renderWardrobeGui())
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
end

local function mountPreviewCharacter(tavernSet: Model): ()
	local playerPoint = findPlayerPoint(tavernSet)
	if not playerPoint then
		warn("WardrobeViewport: PlayerPoint was not found on the wardrobe tavern set.")
		return
	end

	local preview = previewCharacter
	if not preview then
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
	end

	if not preview then
		warn("WardrobeViewport: PreviewCharacter was not ready yet.")
		return
	end

	local previousPreview = tavernSet:FindFirstChild(PREVIEW_CHARACTER_NAME)
	if previousPreview and previousPreview ~= preview then
		previousPreview:Destroy()
	end

	preview.Parent = tavernSet
	preview:PivotTo(playerPoint.CFrame)
	playSwordIdle(preview)
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
			applyViewCamera(activeViewCamera, activeViewCamera.CFrame, activeViewCamera.Focus, activeViewCamera.FieldOfView)
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
	isVisible = true
	WardrobeSelection.SetSelectedItem(nil)

	local tavernSet = ensureTavernSet()
	if not tavernSet then
		isVisible = false
		return false
	end

	local didBindCamera = bindViewCamera(tavernSet)
	if didBindCamera then
		setNormalHudVisible(false)
		mountWardrobeGui()
	else
		isVisible = false
	end

	return didBindCamera
end

function WardrobeViewport.Hide(): ()
	isVisible = false
	WardrobeSelection.SetSelectedItem(nil)
	unmountWardrobeGui()
	setNormalHudVisible(true)
	restoreCamera()
end

function WardrobeViewport.IsVisible(): boolean
	return isVisible
end

local function createPreviewFromCurrentCharacter(): ()
	local character = Players.LocalPlayer.Character
	if character then
		createPreviewCharacter(character)
	end
end

Players.LocalPlayer.CharacterAdded:Connect(function()
	task.defer(createPreviewFromCurrentCharacter)
end)
Players.LocalPlayer.CharacterAppearanceLoaded:Connect(createPreviewCharacter)
if Players.LocalPlayer.Character then
	task.defer(createPreviewFromCurrentCharacter)
	if Players.LocalPlayer:HasAppearanceLoaded() then
		task.defer(createPreviewCharacter, Players.LocalPlayer.Character)
	end
end

ensureTavernSet()

return table.freeze(WardrobeViewport)
