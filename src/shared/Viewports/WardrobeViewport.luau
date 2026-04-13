--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WardrobeViewport = {}

local GUI_NAME = "WardrobeViewportGui"
local VIEWPORT_NAME = "ViewportFrame"
local WORLD_MODEL_NAME = "WorldModel"
local TAVERN_NAME = "Tavern"
local TARGET_HITBOX_NAME = "TargetHitbox"
local PREVIEW_CHARACTER_NAME = "PreviewCharacter"
local CAMERA_NAME = "WardrobeCamera"

local mountedGui: ScreenGui? = nil
local viewportFrame: ViewportFrame? = nil
local worldModel: WorldModel? = nil

local function getViewportFrameFromGui(gui: ScreenGui): ViewportFrame?
	local namedViewport = gui:FindFirstChild(VIEWPORT_NAME)
	if namedViewport and namedViewport:IsA("ViewportFrame") then
		return namedViewport
	end

	return gui:FindFirstChildOfClass("ViewportFrame")
end

local function getOrCreateWorldModel(viewport: ViewportFrame): WorldModel
	local model = viewport:FindFirstChild(WORLD_MODEL_NAME)
	if model and model:IsA("WorldModel") then
		return model
	end

	local newModel = Instance.new("WorldModel")
	newModel.Name = WORLD_MODEL_NAME
	newModel.Parent = viewport
	return newModel
end

local function getPlayerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

local function getViewportTemplate(): ViewportFrame?
	local viewportFolder = ReplicatedStorage:FindFirstChild("Viewports")
	local wardrobeFolder = viewportFolder and viewportFolder:FindFirstChild("Wardrobe")
	local template = wardrobeFolder and wardrobeFolder:FindFirstChild("Viewport")
	if template and template:IsA("ViewportFrame") then
		return template
	end

	return nil
end

local function findTargetHitbox(model: WorldModel): BasePart?
	local tavern = model:FindFirstChild(TAVERN_NAME)
	if tavern then
		local hitbox = tavern:FindFirstChild(TARGET_HITBOX_NAME)
		if hitbox and hitbox:IsA("BasePart") then
			return hitbox
		end
	end

	local hitbox = model:FindFirstChild(TARGET_HITBOX_NAME, true)
	if hitbox and hitbox:IsA("BasePart") then
		return hitbox
	end

	return nil
end

local function prepPreviewCharacter(character: Model): ()
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function frameTarget(viewport: ViewportFrame, target: BasePart): ()
	local camera = viewport:FindFirstChild(CAMERA_NAME) :: Camera?
	if not camera then
		camera = Instance.new("Camera")
		camera.Name = CAMERA_NAME
		camera.Parent = viewport
	end

	local focus = target.Position
	local radius = math.max(target.Size.X, target.Size.Y, target.Size.Z)
	local offset = (target.CFrame.LookVector * math.max(8, radius * 2)) + Vector3.new(0, math.max(2, radius * 0.3), 0)
	camera.CFrame = CFrame.lookAt(focus + offset, focus)
	camera.FieldOfView = 45
	viewport.CurrentCamera = camera
end

local function mountPreviewCharacter()
	local model = WardrobeViewport.GetWorldModel()
	local viewport = WardrobeViewport.GetViewportFrame()
	local hitbox = findTargetHitbox(model)
	local character = Players.LocalPlayer.Character
	if not hitbox or not character then
		return
	end

	local previousPreview = hitbox:FindFirstChild(PREVIEW_CHARACTER_NAME)
	if previousPreview then
		previousPreview:Destroy()
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
	preview.Parent = hitbox
	preview:PivotTo(hitbox.CFrame)
	frameTarget(viewport, hitbox)
end

local function buildGui(): ScreenGui
	local playerGui = getPlayerGui()
	local existingGui = playerGui:FindFirstChild(GUI_NAME)
	if existingGui and existingGui:IsA("ScreenGui") then
		mountedGui = existingGui
		viewportFrame = getViewportFrameFromGui(existingGui)
		if not viewportFrame then
			existingGui:Destroy()
			mountedGui = nil
			return buildGui()
		end

		viewportFrame.Name = VIEWPORT_NAME
		worldModel = getOrCreateWorldModel(viewportFrame)
		return existingGui
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 40
	screenGui.Enabled = false

	local viewportTemplate = getViewportTemplate()
	local viewport = if viewportTemplate then viewportTemplate:Clone() else Instance.new("ViewportFrame")
	viewport.Name = VIEWPORT_NAME
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BorderSizePixel = 0
	viewport.Parent = screenGui

	-- All viewport files should keep the object hierarchy as ViewportFrame > WorldModel.
	local model = getOrCreateWorldModel(viewport)

	screenGui.Parent = playerGui

	mountedGui = screenGui
	viewportFrame = viewport
	worldModel = model

	return screenGui
end

function WardrobeViewport.Show(): ()
	local gui = buildGui()
	mountPreviewCharacter()
	gui.Enabled = true
end

function WardrobeViewport.Hide(): ()
	buildGui().Enabled = false
end

function WardrobeViewport.IsVisible(): boolean
	local gui = mountedGui
	return gui ~= nil and gui.Enabled
end

function WardrobeViewport.GetViewportFrame(): ViewportFrame
	if not viewportFrame then
		buildGui()
	end

	return viewportFrame :: ViewportFrame
end

function WardrobeViewport.GetWorldModel(): WorldModel
	if not worldModel then
		buildGui()
	end

	return worldModel :: WorldModel
end

return table.freeze(WardrobeViewport)
