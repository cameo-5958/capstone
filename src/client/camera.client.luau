--!strict
local UserInputService = game:GetService("UserInputService")

local CameraController = require(script.Parent.CameraController)

local controller = CameraController.new()
controller:Init()

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftBracket then
		controller:CycleMode(-1)
	elseif input.KeyCode == Enum.KeyCode.RightBracket then
		controller:CycleMode(1)
	end
end)
