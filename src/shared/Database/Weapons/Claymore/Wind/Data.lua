local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)

local ABILITY_DURATION = 5
local ABILITY_RANGE = 18
local ABILITY_STRENGTH = 28
local ABILITY_TICK_RATE = 0.5
local ABILITY_DAMAGE_REDUCTION_MULTIPLIER = 0.85

return {
	["Name"] = "Airsweeper",
	["Type"] = "Claymore",
	["Family"] = "Greek",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://106942059499435",

	["BaseDamage"] = 113,
	["__Stats"] = {
		["Health"] = 100,
		["CritDamage"] = 200,
	},
	["Weight"] = 11,
	["WeaponPassive"] = nil,
	["WeaponAbility"] = nil,
	["RightClickAbility"] = {
		Cooldown = 10,
		Execute = function(_, owner, _)
			local SpellServiceServer = require(ReplicatedStorage.Services.Spell.SpellServiceServer)
			print(string.format("[Airsweeper] Right click used by %s", owner.Name))
			local source = string.format("weapon:claymore:wind:rightclick:%s", HttpService:GenerateGUID(false))
			owner:AddModifier(
				"DamageTakenMultiplier",
				Modifier.new(
					"airsweeper:rightclick:damage_reduction",
					"Multiplicative",
					ABILITY_DAMAGE_REDUCTION_MULTIPLIER,
					source
				)
			)

			task.delay(ABILITY_DURATION, function()
				owner:RemoveModifiersFromSource(source)
			end)

			local created = SpellServiceServer.CreateTornado(owner, {
				Center = owner.RootPart.Position + owner.RootPart.CFrame.LookVector * ABILITY_RANGE,
				Duration = ABILITY_DURATION,
				TickRate = ABILITY_TICK_RATE,
				Range = ABILITY_RANGE,
				PullHeight = 9,
				PullSpeed = ABILITY_STRENGTH,
				MinPullSpeed = ABILITY_STRENGTH * 0.35,
				MaxResultantSpeed = ABILITY_STRENGTH * 1.8,
				TargetGroup = "Enemies",
				Source = source,
			})
			print(string.format("[Airsweeper] Tornado create result=%s", tostring(created)))
		end,
	},

	["Desc"] = "A wind-forged claymore that whips up a towering vortex, hauling enemies skyward while shielding its wielder.",
}
