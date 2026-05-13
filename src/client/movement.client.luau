--!strict
-- Attach movement module to player

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local AttackServiceClient = require(ReplicatedStorage.Services.Attack.AttackServiceClient)
local AnimationServiceClient = require(ReplicatedStorage.Services.Animation.AnimationServiceClient)
local PlayerServiceClient = require(ReplicatedStorage.Services.Player.PlayerServiceClient)
local WardrobeViewport = require(ReplicatedStorage.Viewports.WardrobeViewport)
local WeaponServiceClient = require(ReplicatedStorage.Services.Weapon.WeaponServiceClient)
local CameraController = require(script.Parent.CameraController)
local Movement = require(ReplicatedStorage.Classes.Entity.PlayerMovement)
local ClassCombos = require(ReplicatedStorage.Database.Weapons.Default.Combos)
local PlayerConfig = require(ReplicatedStorage.Database.Players.Default.Data)

-- Create a new MovementEngine
local engine = Movement.lnew()
local IsChargingBow = false
local IsBowAiming = false
local BowHoldToken = 0
local BOW_AIM_HOLD_DELAY = 0.2
local PreloadedWeaponAnimationClasses: { [string]: boolean } = {}
local IsWardrobeOpen = false
local DebugMouseUnlocked = false

local function CollectComboAnimationIds(weaponClass: string?): { string }
	if not weaponClass then
		return {}
	end

	local comboSet = ClassCombos[weaponClass]
	if not comboSet then
		return {}
	end

	local animationIds = {}
	local seen = {}
	for _, combo in pairs(comboSet.Combos) do
		for _, attack in ipairs(combo.Attacks) do
			local animationId = attack.AnimationId
			if type(animationId) == "string" then
				if animationId ~= "" and not seen[animationId] then
					seen[animationId] = true
					table.insert(animationIds, animationId)
				end
			else
				for _, candidate in ipairs(animationId) do
					if type(candidate) == "string" and candidate ~= "" and not seen[candidate] then
						seen[candidate] = true
						table.insert(animationIds, candidate)
					end
				end
			end
		end
	end

	return animationIds
end

local function PreloadLocalPlayerAnimations()
	local playerAnimationIds = {}
	for _, animationId in pairs(PlayerConfig.__Animations or {}) do
		if type(animationId) == "string" and animationId ~= "" then
			table.insert(playerAnimationIds, animationId)
		end
	end

	AnimationServiceClient.PreloadLocalAnimations(playerAnimationIds)
end

local function PreloadEquippedWeaponAnimations()
	local equippedWeapon = WeaponServiceClient.GetEquippedWeaponData()
	if not equippedWeapon then
		return
	end

	if PreloadedWeaponAnimationClasses[equippedWeapon.Class] then
		return
	end

	PreloadedWeaponAnimationClasses[equippedWeapon.Class] = true
	AnimationServiceClient.PreloadLocalAnimations(CollectComboAnimationIds(equippedWeapon.Class))
end

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
		controller:SetMode("Aiming")
	elseif controller:GetMode() == "Aiming" then
		controller:SetMode("Default")
	end
end

local function SetMouseLockSuppressed(suppressed: boolean)
	local controller = CameraController.GetSharedController()
	if not controller then
		if suppressed then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
		return
	end

	controller:SetMouseLockSuppressed(suppressed)
end

local function SetCameraUpdateSuppressed(suppressed: boolean)
	local controller = CameraController.GetSharedController()
	if controller then
		controller:SetUpdateSuppressed(suppressed)
	end
end

local function ApplyMouseLockState()
	SetMouseLockSuppressed(IsWardrobeOpen or DebugMouseUnlocked)
end

local function RecreateMovementEngine()
	engine = Movement.lnew()
	if IsWardrobeOpen then
		engine:DisableAllMovement()
	end
end

PreloadLocalPlayerAnimations()
PreloadEquippedWeaponAnimations()
game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
	task.defer(function()
		RecreateMovementEngine()
		PreloadLocalPlayerAnimations()
		PreloadEquippedWeaponAnimations()
	end)
end)
WeaponServiceClient.GetEquippedWeaponChangedSignal():Connect(function()
	engine:UpdateMovementAnimation()
	task.defer(PreloadEquippedWeaponAnimations)
end)

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

local function CancelBowCharge()
	if not IsChargingBow then
		return
	end

	IsChargingBow = false
	BowHoldToken += 1
	if IsBowAiming then
		IsBowAiming = false
		SetBowCameraEnabled(false)
	end
	AttackServiceClient.ReleaseBowCharge(GetBowReleasePayload())
end

local function SetWardrobeOpen(isOpen: boolean)
	if IsWardrobeOpen == isOpen then
		return
	end

	IsWardrobeOpen = isOpen
	if isOpen then
		CancelBowCharge()
		PlayerServiceClient.SetRightClickReleased()
		ApplyMouseLockState()
		SetCameraUpdateSuppressed(true)
		engine:DisableAllMovement()
		if not WardrobeViewport.Show() then
			IsWardrobeOpen = false
			SetCameraUpdateSuppressed(false)
			ApplyMouseLockState()
			engine:EnableAllMovement()
		end
	else
		WardrobeViewport.Hide()
		ApplyMouseLockState()
		SetCameraUpdateSuppressed(false)
		engine:EnableAllMovement()
	end
end

-- Attach to UserInputService
UserInputService.InputBegan:Connect(function(input, processed)
	-- DEBUG_MOUSE_UNLOCK_START (easy delete block)
	if input.KeyCode == Enum.KeyCode.M and not UserInputService:GetFocusedTextBox() then
		DebugMouseUnlocked = not DebugMouseUnlocked
		ApplyMouseLockState()
		return
	end
	-- DEBUG_MOUSE_UNLOCK_END

	if input.KeyCode == Enum.KeyCode.B and not UserInputService:GetFocusedTextBox() then
		SetWardrobeOpen(not IsWardrobeOpen)
		return
	end

	if processed then
		return
	end

	if IsWardrobeOpen then
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

	if IsWardrobeOpen then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		CancelBowCharge()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		PlayerServiceClient.SetRightClickReleased()
	end
end)
