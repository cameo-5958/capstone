--!strict
local Lighting = game:GetService("Lighting")

local CameraController = require(script.Parent.CameraController)

local controller = CameraController.new()
controller:Init()
CameraController.SetSharedController(controller)

local DEFAULT_FOG_COLOR = Color3.fromRGB(170, 190, 210)
local DEFAULT_FOG_START = 190
local DEFAULT_FOG_END = 194

local function applyGameplayFog()
	Lighting.FogColor = DEFAULT_FOG_COLOR
	Lighting.FogStart = DEFAULT_FOG_START
	Lighting.FogEnd = DEFAULT_FOG_END
end

local function configureDefaultWorldView()
	applyGameplayFog()
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

configureDefaultWorldView()
