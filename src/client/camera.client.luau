--!strict
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local CameraController = require(script.Parent.CameraController)

local controller = CameraController.new()
controller:Init()
CameraController.SetSharedController(controller)

local FREECAM_KEY = Enum.KeyCode.P
local FREECAM_RENDERSTEP = "CapstoneDetachedPerspectiveCamera"
local FREECAM_ROTATION_SENSITIVITY = 0.0023
local FREECAM_BASE_SPEED = 120
local FREECAM_FAST_MULTIPLIER = 3.2
local FREECAM_SLOW_MULTIPLIER = 0.35
local FREECAM_MIN_PITCH = math.rad(-89)
local FREECAM_MAX_PITCH = math.rad(89)

local FreecamEnabled = false
local FreecamPosition = Vector3.zero
local FreecamYaw = 0
local FreecamPitch = 0

local function configureDefaultWorldView()
	-- Use a near-hard vision cutoff instead of broad haze.
	Lighting.FogColor = Color3.fromRGB(170, 190, 210)
	Lighting.FogStart = 156
	Lighting.FogEnd = 162
	Lighting.Brightness = 2.15
	Lighting.ExposureCompensation = 0.08

	local effectName = "CapstoneWorldNearBoost"
	local colorCorrection = Lighting:FindFirstChild(effectName)
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = effectName
		colorCorrection.Parent = Lighting
	end
	if colorCorrection:IsA("ColorCorrectionEffect") then
		colorCorrection.Brightness = 0
		colorCorrection.Contrast = 0
		colorCorrection.Saturation = 0
		colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	end
end

local function stopFreecam()
	if not FreecamEnabled then
		return
	end

	FreecamEnabled = false
	RunService:UnbindFromRenderStep(FREECAM_RENDERSTEP)
	controller:SetUpdateSuppressed(false)
	controller:SetMouseLockSuppressed(false)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function startFreecam()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local look = camera.CFrame.LookVector
	FreecamYaw = math.atan2(-look.X, -look.Z)
	FreecamPitch = math.asin(math.clamp(look.Y, -1, 1))
	FreecamPosition = camera.CFrame.Position

	FreecamEnabled = true
	controller:SetUpdateSuppressed(true)
	controller:SetMouseLockSuppressed(true)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	RunService:BindToRenderStep(FREECAM_RENDERSTEP, Enum.RenderPriority.Camera.Value + 2, function(deltaTime: number)
		if not FreecamEnabled then
			return
		end

		local currentCamera = Workspace.CurrentCamera
		if not currentCamera then
			return
		end

		local mouseDelta = UserInputService:GetMouseDelta()
		FreecamYaw -= mouseDelta.X * FREECAM_ROTATION_SENSITIVITY
		FreecamPitch = math.clamp(FreecamPitch - mouseDelta.Y * FREECAM_ROTATION_SENSITIVITY, FREECAM_MIN_PITCH, FREECAM_MAX_PITCH)

		local moveX = 0
		local moveY = 0
		local moveZ = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveX -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveX += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.E) then
			moveY += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
			moveY -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveZ -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveZ += 1
		end

		local planarInput = Vector3.new(moveX, 0, moveZ)
		if planarInput.Magnitude > 1 then
			planarInput = planarInput.Unit
		end
		local verticalInput = if moveY == 0 then 0 else if moveY > 0 then 1 else -1

		local speed = FREECAM_BASE_SPEED
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
			speed *= FREECAM_FAST_MULTIPLIER
		elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			speed *= FREECAM_SLOW_MULTIPLIER
		end

		local rotation = CFrame.fromOrientation(FreecamPitch, FreecamYaw, 0)
		local worldPlanar = rotation:VectorToWorldSpace(planarInput)
		local displacement = (worldPlanar + Vector3.new(0, verticalInput, 0)) * speed * deltaTime
		FreecamPosition += displacement

		currentCamera.CameraType = Enum.CameraType.Scriptable
		currentCamera.CFrame = CFrame.new(FreecamPosition) * rotation
	end)
end

local function toggleFreecam()
	if FreecamEnabled then
		stopFreecam()
	else
		startFreecam()
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	local focusedTextBox = UserInputService:GetFocusedTextBox()
	if input.KeyCode == FREECAM_KEY and not focusedTextBox then
		toggleFreecam()
		return
	end

	if processed then
		return
	end

	if FreecamEnabled then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftBracket then
		controller:CycleMode(-1)
	elseif input.KeyCode == Enum.KeyCode.RightBracket then
		controller:CycleMode(1)
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		controller:ToggleOrbitFocusMode()
	end
end)

configureDefaultWorldView()
