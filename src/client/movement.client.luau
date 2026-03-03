--!strict
-- Attach movement module to player

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Movement = require(ReplicatedStorage.Classes.Entity.PlayerMovement)
local LocalPlayer = Players.LocalPlayer

-- Create a new MovementEngine
local engine = Movement.lnew()

-- Attach to UserInputService
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if input.UserInputState == Enum.UserInputState.Begin then
			-- Attack
			engine:Attack()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if input.UserInputState == Enum.UserInputState.Begin then
			-- Dash
			engine:Dash()
		end
	end
end)
