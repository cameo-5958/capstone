local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DEFAULT_BOW_GRAVITY_SCALE = 0.35
local DEFAULT_BOW_HOMING_STRENGTH = 12
local DEFAULT_VOLLEY_LOCK_DURATION = 0.65
local LOCK_TOKEN_ATTRIBUTE = "SilkBowVolleyLockToken"
local BOW_SHOT_ANIMATIONS = {
	"rbxassetid://135215634088644",
	"rbxassetid://127584242031977",
	"rbxassetid://117890025835582",
}
local SPREAD_ANGLES = { -15, 0, 15 }

local function chooseBowShotAnimation(): string
	return BOW_SHOT_ANIMATIONS[math.random(1, #BOW_SHOT_ANIMATIONS)]
end

local function lockOwnerMovement(owner, duration: number)
	local character = owner.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local lockToken = (character:GetAttribute(LOCK_TOKEN_ATTRIBUTE) or 0) + 1
	character:SetAttribute(LOCK_TOKEN_ATTRIBUTE, lockToken)

	humanoid.WalkSpeed = 0
	humanoid:Move(Vector3.zero, false)
	owner.RootPart.AssemblyLinearVelocity = Vector3.zero

	task.delay(duration, function()
		if character.Parent == nil then
			return
		end

		if character:GetAttribute(LOCK_TOKEN_ATTRIBUTE) ~= lockToken then
			return
		end

		humanoid.WalkSpeed = owner:GetStat("Speed")
	end)
end

return {
	["Name"] = "Silk-String Recurve",
	["Type"] = "Bow",
	["Family"] = "Greek",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://131855443902326",

	["BaseDamage"] = 74,
	["__Stats"] = {
		["CritDamage"] = 50,
		["CritRate"] = 1,
	},
	["Weight"] = 11,
	["WeaponPassive"] = nil,

	["WeaponAbility"] = nil,
	["RightClickAbility"] = {
		Execute = function(self, owner, _)
			local AnimationServiceServer = require(ReplicatedStorage.Services.Animation.AnimationServiceServer)
			local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
			local ProjectileServiceServer = require(ReplicatedStorage.Services.Projectile.ProjectileServiceServer)

			local attackContext = self:GetAttackContext()
			local lockDuration = attackContext.MovementLockDuration or attackContext.LockDuration or DEFAULT_VOLLEY_LOCK_DURATION
			local player = Players:FindFirstChild(owner.Name)
			if player then
				AnimationServiceServer.PlayPlayerOnce(player, chooseBowShotAnimation())
			end
			lockOwnerMovement(owner, lockDuration)

			local origin = owner.RootPart.Position + Vector3.new(0, attackContext.ProjectileSpawnHeight or 2.25, 0)
			local target = EnemyServiceServer.GetClosest(owner.RootPart.Position, attackContext.AcquireRange or 96)
			local baseDirection = owner.RootPart.CFrame.LookVector
			local speed = attackContext.ProjectileSpeed or 110

			if target then
				local targetPosition = target.RootPart.Position + Vector3.new(0, attackContext.ProjectileAimHeight or 1.5, 0)
				local delta = targetPosition - origin
				if delta.Magnitude > 0.001 then
					baseDirection = delta.Unit
				end
			end

			for _, angle in ipairs(SPREAD_ANGLES) do
				local spreadDirection = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(angle)) * baseDirection).Unit
				ProjectileServiceServer.FireArrow({
					Position = origin,
					Velocity = spreadDirection * speed,
					Speed = speed,
					MaxDistance = (attackContext.Range or 60) * owner:GetStat("ArrowTravelDistance"),
					GravityScale = attackContext.GravityScale or DEFAULT_BOW_GRAVITY_SCALE,
					Radius = attackContext.ProjectileRadius or 0.5,
					DamageScale = 1,
					Owner = owner,
					Weapon = self,
					Target = target,
					HomingStrength = attackContext.HomingStrength or DEFAULT_BOW_HOMING_STRENGTH,
				})
			end
		end,
	},

	["Desc"] = "The silk-string of this bow provides exceptional accuracy and power and is embued with the power to split into multiple arrows.",
}
