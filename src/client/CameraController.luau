--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EnemyServiceClient = require(ReplicatedStorage.Services.Enemy.EnemyServiceClient)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityTypes.Entity

type CameraModeName = "Default" | "Aiming" | "Focus"

type OrbitModeConfig = {
	Name: CameraModeName,
	Fov: number,
	Offset: Vector3,
	ZoomMin: number,
	ZoomMax: number,
	ZoomDefault: number,
	LookAtHeight: number,
	MouseSensitivity: number,
	Smoothing: number,
	MinPitch: number,
	MaxPitch: number,
}

type FocusModeConfig = {
	Name: CameraModeName,
	Fov: number,
	Offset: Vector3,
	ZoomMin: number,
	ZoomMax: number,
	ZoomDefault: number,
	LookAtHeight: number,
	EnemyLookAtHeight: number,
	Smoothing: number,
	EnemySearchRadius: number,
	FramePadding: number,
}

type CameraController = {
	Player: Player,
	Camera: Camera?,
	Character: Model?,
	RootPart: BasePart?,
	ModeOrder: { CameraModeName },
	Modes: {
		[CameraModeName]: OrbitModeConfig | FocusModeConfig,
	},
	CurrentModeIndex: number,
	CurrentModeName: CameraModeName,
	ZoomDistances: {
		[CameraModeName]: number,
	},
	Yaw: number,
	Pitch: number,
	LastCameraCFrame: CFrame?,
	LastFocusMidpoint: Vector3?,
	RenderStepName: string,
	CharacterConnection: RBXScriptConnection?,
	InputChangedConnection: RBXScriptConnection?,
	Init: (self: CameraController) -> (),
	BindCharacter: (self: CameraController, character: Model) -> (),
	CycleMode: (self: CameraController, direction: number) -> CameraModeName,
	SetMode: (self: CameraController, modeName: CameraModeName) -> CameraModeName,
	GetMode: (self: CameraController) -> CameraModeName,
	Update: (self: CameraController, deltaTime: number) -> (),
	ResolveFocusTarget: (self: CameraController, config: FocusModeConfig) -> Entity?,
	GetZoomDistance: (self: CameraController, modeName: CameraModeName?) -> number,
	AdjustZoom: (self: CameraController, delta: number) -> number,
	BuildOrbitCamera: (self: CameraController, config: OrbitModeConfig) -> (CFrame, number),
	BuildFocusCamera: (self: CameraController, config: FocusModeConfig, deltaTime: number) -> (CFrame, number),
	ApplyMouseLock: (self: CameraController) -> (),
	new: () -> CameraController,
}

local MODE_ORDER: { CameraModeName } = {
	"Default",
	"Aiming",
	"Focus",
}

local MODE_CONFIGS: {
	[CameraModeName]: OrbitModeConfig | FocusModeConfig,
} = {
	Default = {
		Name = "Default",
		Fov = 70,
		Offset = Vector3.new(2.5, 2.8, 12),
		ZoomMin = 6,
		ZoomMax = 24,
		ZoomDefault = 12,
		LookAtHeight = 2.5,
		MouseSensitivity = 0.0035,
		Smoothing = 10,
		MinPitch = math.rad(-70),
		MaxPitch = math.rad(70),
	},
	Aiming = {
		Name = "Aiming",
		Fov = 58,
		Offset = Vector3.new(1.1, 2.05, 5),
		ZoomMin = 2.5,
		ZoomMax = 8,
		ZoomDefault = 3.2,
		LookAtHeight = 2.2,
		MouseSensitivity = 0.0022,
		Smoothing = 14,
		MinPitch = math.rad(-55),
		MaxPitch = math.rad(50),
	},
	Focus = {
		Name = "Focus",
		Fov = 62,
		Offset = Vector3.new(2.5, 3.5, 14),
		ZoomMin = 10,
		ZoomMax = 32,
		ZoomDefault = 14,
		LookAtHeight = 2.5,
		EnemyLookAtHeight = 2,
		Smoothing = 9,
		EnemySearchRadius = 80,
		FramePadding = 1.35,
	},
}

local CameraController = {}
CameraController.__index = CameraController

local function GetRootPart(character: Model?): BasePart?
	if not character then
		return nil
	end

	local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

local function GetCharacterPivot(self: CameraController, lookAtHeight: number): Vector3?
	local rootPart = self.RootPart
	if not rootPart then
		return nil
	end

	return rootPart.Position + Vector3.yAxis * lookAtHeight
end

local function ShouldForceFaceCamera(self: CameraController): boolean
	local equippedWeapon = WeaponServiceClient.GetEquippedWeaponData()
	return equippedWeapon ~= nil
		and equippedWeapon.Class == "Bow"
		and self.CurrentModeName == "Aiming"
end

local function UpdateFacingLockAttribute(self: CameraController)
	if self.Character then
		self.Character:SetAttribute("ForceFaceCamera", ShouldForceFaceCamera(self))
	end
end

local function GetSmoothingAlpha(speed: number, deltaTime: number): number
	return 1 - math.exp(-speed * deltaTime)
end

local function GetModeZoomBounds(modeConfig: OrbitModeConfig | FocusModeConfig): (number, number)
	return modeConfig.ZoomMin, modeConfig.ZoomMax
end

local function LerpAngle(current: number, target: number, alpha: number): number
	local delta = math.atan2(math.sin(target - current), math.cos(target - current))
	return current + delta * alpha
end

local function ResolveCameraCollision(origin: Vector3, desiredPosition: Vector3, character: Model?): Vector3
	local direction = desiredPosition - origin
	if direction.Magnitude <= 0.001 then
		return desiredPosition
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = if character then { character } else {}

	local result = workspace:Raycast(origin, direction, raycastParams)
	if not result then
		return desiredPosition
	end

	return result.Position + result.Normal * 0.5
end

function CameraController.ApplyMouseLock(self: CameraController)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

function CameraController.BindCharacter(self: CameraController, character: Model)
	self.Character = character
	self.RootPart = GetRootPart(character)
	UpdateFacingLockAttribute(self)

	local rootPart = self.RootPart
	if rootPart then
		local lookVector = rootPart.CFrame.LookVector
		self.Yaw = math.atan2(-lookVector.X, -lookVector.Z)
	end
end

function CameraController.ResolveFocusTarget(self: CameraController, config: FocusModeConfig): Entity?
	local rootPart = self.RootPart
	if not rootPart then
		return nil
	end

	local closest = EnemyServiceClient.GetClosest(rootPart.Position, config.EnemySearchRadius)
	if not closest or not closest.Character or not closest.RootPart then
		return nil
	end

	if closest.Character.Parent == nil then
		return nil
	end

	return closest
end

function CameraController.GetZoomDistance(self: CameraController, modeName: CameraModeName?): number
	local resolvedModeName = modeName or self.CurrentModeName
	local modeConfig = self.Modes[resolvedModeName]
	local currentZoom = self.ZoomDistances[resolvedModeName]
	if currentZoom then
		return currentZoom
	end

	return modeConfig.ZoomDefault
end

function CameraController.AdjustZoom(self: CameraController, delta: number): number
	local modeName = self.CurrentModeName
	local modeConfig = self.Modes[modeName]
	local zoomMin, zoomMax = GetModeZoomBounds(modeConfig)
	local nextZoom = math.clamp(self:GetZoomDistance(modeName) + delta, zoomMin, zoomMax)
	self.ZoomDistances[modeName] = nextZoom
	return nextZoom
end

function CameraController.BuildOrbitCamera(self: CameraController, config: OrbitModeConfig): (CFrame, number)
	local pivot = GetCharacterPivot(self, config.LookAtHeight)
	if not pivot then
		return CFrame.new(), config.Fov
	end

	local delta = UserInputService:GetMouseDelta()
	self.Yaw -= delta.X * config.MouseSensitivity
	self.Pitch = math.clamp(self.Pitch - delta.Y * config.MouseSensitivity, config.MinPitch, config.MaxPitch)

	local rotation = CFrame.fromOrientation(self.Pitch, self.Yaw, 0)
	local zoomDistance = self:GetZoomDistance(config.Name)
	local desiredOffset = Vector3.new(config.Offset.X, config.Offset.Y, zoomDistance)
	local desiredPosition = pivot + rotation:VectorToWorldSpace(desiredOffset)
	local cameraPosition = ResolveCameraCollision(pivot, desiredPosition, self.Character)

	return CFrame.lookAt(cameraPosition, pivot), config.Fov
end

function CameraController.BuildFocusCamera(self: CameraController, config: FocusModeConfig, deltaTime: number): (CFrame, number)
	local rootPart = self.RootPart
	local playerFocus = GetCharacterPivot(self, config.LookAtHeight)
	if not rootPart or not playerFocus then
		return CFrame.new(), config.Fov
	end

	local focusTarget = self:ResolveFocusTarget(config)
	if not focusTarget then
		self.LastFocusMidpoint = nil
		local fallback = MODE_CONFIGS.Default :: OrbitModeConfig
		return self:BuildOrbitCamera(fallback)
	end

	local enemyFocus = focusTarget.RootPart.Position + Vector3.yAxis * config.EnemyLookAtHeight
	local midpoint = playerFocus:Lerp(enemyFocus, 0.5)
	local focusAlpha = GetSmoothingAlpha(config.Smoothing, deltaTime)
	if self.LastFocusMidpoint then
		midpoint = self.LastFocusMidpoint:Lerp(midpoint, focusAlpha)
	end
	self.LastFocusMidpoint = midpoint

	local flatDirection = Vector3.new(enemyFocus.X - playerFocus.X, 0, enemyFocus.Z - playerFocus.Z)
	if flatDirection.Magnitude > 0.001 then
		local targetYaw = math.atan2(-flatDirection.Unit.X, -flatDirection.Unit.Z)
		self.Yaw = LerpAngle(self.Yaw, targetYaw, focusAlpha)
	end

	local forward = if flatDirection.Magnitude > 0.001 then flatDirection.Unit else rootPart.CFrame.LookVector
	local right = forward:Cross(Vector3.yAxis).Unit
	local separation = (enemyFocus - playerFocus).Magnitude
	local halfFovRadians = math.rad(config.Fov * 0.5)
	local framingDistance = (separation * config.FramePadding) / math.max(math.tan(halfFovRadians), 0.1)
	local zoomDistance = math.max(self:GetZoomDistance(config.Name), framingDistance)
	local desiredPosition = midpoint
		+ right * config.Offset.X
		+ Vector3.yAxis * config.Offset.Y
		- forward * zoomDistance
	local cameraPosition = ResolveCameraCollision(midpoint, desiredPosition, self.Character)

	return CFrame.lookAt(cameraPosition, midpoint), config.Fov
end

function CameraController.GetMode(self: CameraController): CameraModeName
	return self.CurrentModeName
end

function CameraController.SetMode(self: CameraController, modeName: CameraModeName): CameraModeName
	for index, candidate in ipairs(self.ModeOrder) do
		if candidate == modeName then
			self.CurrentModeIndex = index
			self.CurrentModeName = modeName
			UpdateFacingLockAttribute(self)
			return modeName
		end
	end

	return self.CurrentModeName
end

function CameraController.CycleMode(self: CameraController, direction: number): CameraModeName
	local totalModes = #self.ModeOrder
	local nextIndex = ((self.CurrentModeIndex - 1 + direction) % totalModes) + 1
	self.CurrentModeIndex = nextIndex
	self.CurrentModeName = self.ModeOrder[nextIndex]
	UpdateFacingLockAttribute(self)
	return self.CurrentModeName
end

function CameraController.Update(self: CameraController, deltaTime: number)
	self.Camera = workspace.CurrentCamera
	local camera = self.Camera
	if not camera then
		return
	end

	if not self.Character or self.Character.Parent == nil then
		local character = self.Player.Character
		if character then
			self:BindCharacter(character)
		end
	end

	self.RootPart = GetRootPart(self.Character)
	if not self.RootPart then
		return
	end
	UpdateFacingLockAttribute(self)

	self:ApplyMouseLock()
	camera.CameraType = Enum.CameraType.Scriptable

	local modeConfig = self.Modes[self.CurrentModeName]
	local desiredCFrame: CFrame
	local desiredFov: number

	if modeConfig.Name == "Focus" then
		desiredCFrame, desiredFov = self:BuildFocusCamera(modeConfig :: FocusModeConfig, deltaTime)
	else
		self.LastFocusMidpoint = nil
		desiredCFrame, desiredFov = self:BuildOrbitCamera(modeConfig :: OrbitModeConfig)
	end

	local smoothing = modeConfig.Smoothing
	local alpha = GetSmoothingAlpha(smoothing, deltaTime)
	if self.LastCameraCFrame then
		camera.CFrame = self.LastCameraCFrame:Lerp(desiredCFrame, alpha)
	else
		camera.CFrame = desiredCFrame
	end
	camera.FieldOfView += (desiredFov - camera.FieldOfView) * alpha

	self.LastCameraCFrame = camera.CFrame
end

function CameraController.Init(self: CameraController)
	local player = self.Player
	local character = player.Character or player.CharacterAdded:Wait()
	self:BindCharacter(character)

	if self.CharacterConnection then
		self.CharacterConnection:Disconnect()
	end
	if self.InputChangedConnection then
		self.InputChangedConnection:Disconnect()
	end

	self.CharacterConnection = player.CharacterAdded:Connect(function(nextCharacter)
		self.LastCameraCFrame = nil
		self:BindCharacter(nextCharacter)
	end)

	self.InputChangedConnection = UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self:AdjustZoom(-input.Position.Z * 1.5)
		end
	end)

	RunService:BindToRenderStep(self.RenderStepName, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		self:Update(deltaTime)
	end)
end

function CameraController.new(): CameraController
	local self = setmetatable({}, CameraController)
	self.Player = Players.LocalPlayer
	self.Camera = workspace.CurrentCamera
	self.Character = nil
	self.RootPart = nil
	self.ModeOrder = table.clone(MODE_ORDER)
	self.Modes = table.clone(MODE_CONFIGS)
	self.CurrentModeIndex = 1
	self.CurrentModeName = self.ModeOrder[self.CurrentModeIndex]
	self.ZoomDistances = {
		Default = (MODE_CONFIGS.Default :: OrbitModeConfig).ZoomDefault,
		Aiming = (MODE_CONFIGS.Aiming :: OrbitModeConfig).ZoomDefault,
		Focus = (MODE_CONFIGS.Focus :: FocusModeConfig).ZoomDefault,
	}
	self.Yaw = 0
	self.Pitch = math.rad(-12)
	self.LastCameraCFrame = nil
	self.LastFocusMidpoint = nil
	self.RenderStepName = "CapstoneCameraController"
	self.CharacterConnection = nil
	self.InputChangedConnection = nil

	return (self :: any) :: CameraController
end

return CameraController
