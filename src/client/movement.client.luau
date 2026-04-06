--!strict
-- Attach movement module to player

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local AttackServiceClient = require(ReplicatedStorage.Services.Attack.AttackServiceClient)
local PlayerServiceClient = require(ReplicatedStorage.Services.Player.PlayerServiceClient)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local CameraController = require(script.Parent.CameraController)
local Movement = require(ReplicatedStorage.Classes.Entity.PlayerMovement)

-- Create a new MovementEngine
local engine = Movement.lnew()
local IsChargingBow = false
local IsBowAiming = false
local BowHoldToken = 0
local BOW_AIM_HOLD_DELAY = 0.2

local function IsBowEquipped(): boolean
	local equippedWeapon = WeaponServiceClient.GetEquippedWeaponData()
	return equippedWeapon ~= nil and equippedWeapon.Class == "Bow"
end

local function SetBowCameraEnabled(enabled: boolean)
	local controller = CameraController.GetSharedController()
	if not controller then
		return
	end

	if enabled then
		controller:SnapAimingToNearestEnemy()
		controller:SetMode("Aiming")
	elseif controller:GetMode() == "Aiming" then
		controller:SetMode("Default")
	end
end

local function GetBowReleasePayload(): { [string]: any }
	local camera = Workspace.CurrentCamera
	if not camera then
		return {}
	end

	return {
		CameraLookVector = camera.CFrame.LookVector,
		CameraPosition = camera.CFrame.Position,
	}
end

-- Attach to UserInputService
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if input.UserInputState == Enum.UserInputState.Begin then
			if IsBowEquipped() then
				IsChargingBow = true
				IsBowAiming = false
				BowHoldToken += 1
				local holdToken = BowHoldToken
				task.delay(BOW_AIM_HOLD_DELAY, function()
					if not IsChargingBow or BowHoldToken ~= holdToken or not IsBowEquipped() then
						return
					end

					IsBowAiming = true
					SetBowCameraEnabled(true)
					AttackServiceClient.BeginBowCharge()
				end)
			else
				-- Attack
				if engine:Attack() then
					AttackServiceClient.PrimaryAttack()
				end
			end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if input.UserInputState == Enum.UserInputState.Begin then
			PlayerServiceClient.SetRightClickHeld()
			-- Dash
			if engine:Dash() then
				PlayerServiceClient.RequestDashIFrames()
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if IsChargingBow then
				IsChargingBow = false
				BowHoldToken += 1
				if IsBowAiming then
					IsBowAiming = false
					SetBowCameraEnabled(false)
				end
				AttackServiceClient.ReleaseBowCharge(GetBowReleasePayload())
			end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		PlayerServiceClient.SetRightClickReleased()
	end
end)
