local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SHOCKWAVE_ANIMATION_ID = "rbxassetid://91014619744040"
local SHOCKWAVE_DAMAGE_SCALE = 1
local SHOCKWAVE_DELAY = 0.2
local SHOCKWAVE_DURATION = 0.45
local SHOCKWAVE_COOLDOWN = 15
local SHOCKWAVE_RANGE = 18
local SHOCKWAVE_RING_HEIGHT = 0.15

local function playShockwaveAnimation(owner)
	local player = Players:FindFirstChild(owner.Name)
	if not player then
		return
	end

	local AnimationServiceServer = require(ReplicatedStorage.Services.Animation.AnimationServiceServer)
	AnimationServiceServer.PlayPlayerOnce(player, SHOCKWAVE_ANIMATION_ID)
end

local function createShockwaveEffect(origin)
	local shockwave = Instance.new("Part")
	shockwave.Name = "KratosShockwave"
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.CanQuery = false
	shockwave.CanTouch = false
	shockwave.CastShadow = false
	shockwave.Material = Enum.Material.Neon
	shockwave.Color = Color3.fromRGB(255, 214, 107)
	shockwave.Transparency = 0.2
	shockwave.Shape = Enum.PartType.Cylinder
	shockwave.Size = Vector3.new(SHOCKWAVE_RING_HEIGHT, 2, 2)
	shockwave.CFrame = CFrame.new(origin + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	shockwave.Parent = Workspace

	local tween = TweenService:Create(shockwave, TweenInfo.new(SHOCKWAVE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(SHOCKWAVE_RING_HEIGHT, SHOCKWAVE_RANGE * 2, SHOCKWAVE_RANGE * 2),
		Transparency = 1,
	})
	tween:Play()

	Debris:AddItem(shockwave, SHOCKWAVE_DURATION + 0.1)
end

return {
	["Name"] = "Kratos",
	["Type"] = "Sword",
	["Family"] = "Power",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://90395076129556",

	["BaseDamage"] = 100,
	["__Stats"] = {
		["CritDamage"] = 200,
		["Strength"] = 200,
	},
	["Weight"] = 11,
	["WeaponPassive"] = nil,
	["WeaponAbility"] = nil,
	["RightClickAbility"] = {
		Cooldown = SHOCKWAVE_COOLDOWN,
		Execute = function(self, owner, _)
			local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)

			playShockwaveAnimation(owner)

			local origin = owner.RootPart.Position
			createShockwaveEffect(origin)

			task.wait(SHOCKWAVE_DELAY)

			for _, target in pairs(EnemyServiceServer.GetInRadius(origin, SHOCKWAVE_RANGE)) do
				if target == owner then
					continue
				end

				self:ExecuteAttack(target, SHOCKWAVE_DAMAGE_SCALE, owner, {
					DoesKnockback = false,
					AttackContext = {
						StaminaCost = 0,
					},
				})
			end
		end,
	},

	["Desc"] = "A blade forged with the power of one of the strongest demigods. The raw strength makes mortals tremble in fear.",
}
