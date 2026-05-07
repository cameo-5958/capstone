--!strict

local ViewCamera = {}

ViewCamera.Name = "ViewCamera"
ViewCamera.CFrame = CFrame.new(
	53.7668152,
	6.84264565,
	-83.2453384,
	-0.766019106,
	-0.0437333472,
	0.641328454,
	-0,
	0.997683108,
	0.0680338219,
	-0.642817736,
	0.0521152057,
	-0.764244378
)
ViewCamera.Focus = CFrame.new(52.4841652, 6.70657873, -81.7168579)
ViewCamera.FieldOfView = 60
ViewCamera.CameraType = Enum.CameraType.Fixed
ViewCamera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
ViewCamera.HeadLocked = true
ViewCamera.HeadScale = 1
ViewCamera.VRTiltAndRollEnabled = false

function ViewCamera.ApplyTo(camera: Camera): Camera
	camera.Name = ViewCamera.Name
	camera.CFrame = ViewCamera.CFrame
	camera.Focus = ViewCamera.Focus
	camera.FieldOfView = ViewCamera.FieldOfView
	camera.CameraType = ViewCamera.CameraType
	camera.FieldOfViewMode = ViewCamera.FieldOfViewMode
	camera.HeadLocked = ViewCamera.HeadLocked
	camera.HeadScale = ViewCamera.HeadScale
	camera.VRTiltAndRollEnabled = ViewCamera.VRTiltAndRollEnabled

	return camera
end

function ViewCamera.Create(): Camera
	local camera = Instance.new("Camera")
	return ViewCamera.ApplyTo(camera)
end

return table.freeze(ViewCamera)
