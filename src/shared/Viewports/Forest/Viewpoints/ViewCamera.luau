--!strict

local ViewCamera = {}

ViewCamera.Name = "ViewCamera"
ViewCamera.CFrame = CFrame.new(
	-142.600784,
	15.6940947,
	-186.403793,
	-0.844279408,
	0.0504086502,
	-0.533527195,
	-3.72528985e-09,
	0.995566368,
	0.0940629691,
	0.535903275,
	0.0794154257,
	-0.840536118
)
ViewCamera.Focus = CFrame.new(-141.533737, 15.50597, -184.722733)
ViewCamera.FieldOfView = 70
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

