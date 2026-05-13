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
	MouseLockSuppressed: boolean,
	UpdateSuppressed: boolean,
	RenderStepName: string,
	CharacterConnection: RBXScriptConnection?,
	InputChangedConnection: RBXScriptConnection?,
	Init: (self: CameraController) -> (),
	BindCharacter: (self: CameraController, character: Model) -> (),
	CycleMode: (self: CameraController, direction: number) -> CameraModeName,
	ToggleOrbitFocusMode: (self: CameraController) -> CameraModeName,
	SetMode: (self: CameraController, modeName: CameraModeName) -> CameraModeName,
	GetMode: (self: CameraController) -> CameraModeName,
	Update: (self: CameraController, deltaTime: number) -> (),
	SetMouseLockSuppressed: (self: CameraController, suppressed: boolean) -> (),
	SetUpdateSuppressed: (self: CameraController, suppressed: boolean) -> (),
	ResolveFocusTarget: (self: CameraController, config: FocusModeConfig) -> Entity?,
	GetZoomDistance: (self: CameraController, modeName: CameraModeName?) -> number,
	AdjustZoom: (self: CameraController, delta: number) -> number,
	BuildOrbitCamera: (self: CameraController, config: OrbitModeConfig) -> (CFrame, number),
	BuildFocusCamera: (self: CameraController, config: FocusModeConfig, deltaTime: number) -> (CFrame, number),
	SnapAimingToNearestEnemy: (self: CameraController) -> (),
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
		Fov = 66,
		Offset = Vector3.new(2.2, 2.6, 8.5),
		ZoomMin = 10.4,
		ZoomMax = 10.4,
		ZoomDefault = 10.4,
		LookAtHeight = 0.65,
		MouseSensitivity = 0.0035,
		Smoothing = 7,
		MinPitch = math.rad(-70),
		MaxPitch = math.rad(70),
	},
	Aiming = {
		Name = "Aiming",
		Fov = 58,
		Offset = Vector3.new(1.1, 2.05, 5),
		ZoomMin = 2.5,
		ZoomMax = 8,
		ZoomDefault = 3.8,
		LookAtHeight = 0.5,
		MouseSensitivity = 0.0022,
		Smoothing = 10,
		MinPitch = math.rad(-55),
		MaxPitch = math.rad(50),
	},
	Focus = {
		Name = "Focus",
		Fov = 62,
		Offset = Vector3.new(2.5, 3.5, 14),
		ZoomMin = 10,
		ZoomMax = 26,
		ZoomDefault = 14,
		LookAtHeight = 0.8,
		EnemyLookAtHeight = 0.9,
		Smoothing = 6,
		EnemySearchRadius = 80,
		FramePadding = 0.9,
	},
}

local CameraController = {}
CameraController.__index = CameraController
local SharedController: CameraController? = nil

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

local function GetTorsoPart(character: Model?): BasePart?
	if not character then
		return nil
	end

	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso and upperTorso:IsA("BasePart") then
		return upperTorso
	end

	local torso = character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end

	return GetRootPart(character)
end

local function GetCharacterPivot(self: CameraController, lookAtHeight: number): Vector3?
	local torsoPart = GetTorsoPart(self.Character)
	if not torsoPart then
		return nil
	end

	return torsoPart.Position + Vector3.yAxis * lookAtHeight
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

local CAMERA_COLLISION_PADDING = 0.5
local MIN_COLLISION_DISTANCE = 2.25
local MIN_OCCLUDER_SIZE_MAGNITUDE = 2.4
local MAX_COLLISION_RAYCAST_ITERATIONS = 6

local function IsSignificantOccluder(instance: Instance): boolean
	if not instance:IsA("BasePart") then
		return false
	end

	-- Ignore tiny or non-collidable clutter so pickups/trinkets do not force hard zoom-ins.
	if not instance.CanCollide then
		return false
	end

	if instance.Transparency >= 0.98 then
		return false
	end

	return instance.Size.Magnitude >= MIN_OCCLUDER_SIZE_MAGNITUDE
end

local function ResolveCameraCollision(origin: Vector3, desiredPosition: Vector3, character: Model?): Vector3
	local direction = desiredPosition - origin
	local desiredDistance = direction.Magnitude
	if desiredDistance <= 0.001 then
		return desiredPosition
	end

	local ignoredInstances: { Instance } = if character then { character } else {}
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = ignoredInstances

	for _ = 1, MAX_COLLISION_RAYCAST_ITERATIONS do
		local result = workspace:Raycast(origin, direction, raycastParams)
		if not result then
			return desiredPosition
		end

		if not IsSignificantOccluder(result.Instance) then
			table.insert(ignoredInstances, result.Instance)
			raycastParams.FilterDescendantsInstances = ignoredInstances
			continue
		end

		local hitDistance = (result.Position - origin).Magnitude
		local resolvedDistance = math.max(MIN_COLLISION_DISTANCE, hitDistance - CAMERA_COLLISION_PADDING)
		resolvedDistance = math.min(resolvedDistance, desiredDistance)
		return origin + direction.Unit * resolvedDistance
	end

	return desiredPosition
end

function CameraController.ApplyMouseLock(self: CameraController)
	if self.MouseLockSuppressed then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end

	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

function CameraController.SetMouseLockSuppressed(self: CameraController, suppressed: boolean)
	self.MouseLockSuppressed = suppressed
	if suppressed then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

function CameraController.SetUpdateSuppressed(self: CameraController, suppressed: boolean)
	if self.UpdateSuppressed == suppressed then
		return
	end

	self.UpdateSuppressed = suppressed
	self.LastCameraCFrame = nil
	self.LastFocusMidpoint = nil
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

function CameraController.ToggleOrbitFocusMode(self: CameraController): CameraModeName
	if self.CurrentModeName == "Focus" then
		return self:SetMode("Default")
	end

	return self:SetMode("Focus")
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
		self:SetMode("Default")
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
	local separation = flatDirection.Magnitude
	local halfFovRadians = math.rad(config.Fov * 0.5)
	local framingDistance = (separation * config.FramePadding) / math.max(math.tan(halfFovRadians), 0.1)
	local baseZoomDistance = self:GetZoomDistance(config.Name)
	local zoomDistance = math.min(
		config.ZoomMax,
		math.max(baseZoomDistance, baseZoomDistance + (framingDistance - baseZoomDistance) * 0.45)
	)
	local dynamicHeight = math.min(4.5, separation * 0.08)
	local desiredPosition = midpoint
		+ right * config.Offset.X
		+ Vector3.yAxis * (config.Offset.Y + dynamicHeight)
		- forward * zoomDistance
	local cameraPosition = ResolveCameraCollision(midpoint, desiredPosition, self.Character)

	return CFrame.lookAt(cameraPosition, midpoint), config.Fov
end

function CameraController.SnapAimingToNearestEnemy(self: CameraController)
	local rootPart = self.RootPart
	if not rootPart then
		return
	end

	local target = EnemyServiceClient.GetClosest(rootPart.Position, 96)
	if not target or not target.RootPart then
		return
	end

	local playerFocus = GetCharacterPivot(self, (self.Modes.Aiming :: OrbitModeConfig).LookAtHeight)
	if not playerFocus then
		return
	end

	local enemyFocus = target.RootPart.Position + Vector3.new(0, 1.75, 0)
	local delta = enemyFocus - playerFocus
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude <= 0.001 then
		return
	end

	self.Yaw = math.atan2(-flatDelta.Unit.X, -flatDelta.Unit.Z)
	local distance = math.max(delta.Magnitude, 0.001)
	self.Pitch = math.clamp(
		math.asin(math.clamp(delta.Y / distance, -1, 1)),
		(self.Modes.Aiming :: OrbitModeConfig).MinPitch,
		(self.Modes.Aiming :: OrbitModeConfig).MaxPitch
	)
	self.LastCameraCFrame = nil
end

function CameraController.GetMode(self: CameraController): CameraModeName
	return self.CurrentModeName
end

function CameraController.SetMode(self: CameraController, modeName: CameraModeName): CameraModeName
	if modeName == "Focus" then
		local focusConfig = self.Modes.Focus :: FocusModeConfig
		if not self:ResolveFocusTarget(focusConfig) then
			modeName = "Default"
		end
	end

	for index, candidate in ipairs(self.ModeOrder) do
		if candidate == modeName then
			self.CurrentModeIndex = index
			self.CurrentModeName = modeName
			if modeName ~= "Focus" then
				self.LastFocusMidpoint = nil
			end
			UpdateFacingLockAttribute(self)
			return modeName
		end
	end

	return self.CurrentModeName
end

function CameraController.CycleMode(self: CameraController, direction: number): CameraModeName
	local totalModes = #self.ModeOrder
	local nextIndex = ((self.CurrentModeIndex - 1 + direction) % totalModes) + 1
	return self:SetMode(self.ModeOrder[nextIndex])
end

function CameraController.Update(self: CameraController, deltaTime: number)
	if self.UpdateSuppressed then
		self:ApplyMouseLock()
		return
	end

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
			if self.CurrentModeName == "Default" then
				return
			end
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
	self.MouseLockSuppressed = false
	self.UpdateSuppressed = false
	self.RenderStepName = "CapstoneCameraController"
	self.CharacterConnection = nil
	self.InputChangedConnection = nil

	return (self :: any) :: CameraController
end

function CameraController.SetSharedController(controller: CameraController)
	SharedController = controller
end

function CameraController.GetSharedController(): CameraController?
	return SharedController
end

return CameraController
