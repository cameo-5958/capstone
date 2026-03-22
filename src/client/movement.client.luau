--!strict
-- Attach movement module to player

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local AttackServiceClient = require(ReplicatedStorage.Services.Attack.AttackServiceClient)
local Movement = require(ReplicatedStorage.Classes.Entity.PlayerMovement)

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
			AttackServiceClient.PrimaryAttack()
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if input.UserInputState == Enum.UserInputState.Begin then
			-- Dash
			engine:Dash()
		end
	end
end)
