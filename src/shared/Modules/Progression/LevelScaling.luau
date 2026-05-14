--!strict
-- Applies level-based stat scaling to an entity at spawn.
--
-- HP and PhysicalAttack scale exponentially by 10-level intervals.
-- Levels are capped at 120 so spawn progression has a clear ceiling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)

local MAX_LEVEL = 120
local LEVELS_PER_SCALE_INTERVAL = 10
local HEALTH_MULTIPLIER_PER_INTERVAL = 1.5
local DAMAGE_MULTIPLIER_PER_INTERVAL = 1.2

local LevelScaling = {}

function LevelScaling.ClampLevel(level: number): number
	return math.clamp(math.floor(level), 1, MAX_LEVEL)
end

function LevelScaling.GetScaleFactor(level: number): number
	return LevelScaling.GetHealthScaleFactor(level)
end

function LevelScaling.GetHealthScaleFactor(level: number): number
	level = LevelScaling.ClampLevel(level)
	return HEALTH_MULTIPLIER_PER_INTERVAL ^ ((level - 1) / LEVELS_PER_SCALE_INTERVAL)
end

function LevelScaling.GetDamageScaleFactor(level: number): number
	level = LevelScaling.ClampLevel(level)
	return DAMAGE_MULTIPLIER_PER_INTERVAL ^ ((level - 1) / LEVELS_PER_SCALE_INTERVAL)
end

-- Applies level modifiers to the entity in-place.
-- Must be called after all base stats have been set on the entity.
function LevelScaling.ApplyScaling(entity: any)
	local level = LevelScaling.ClampLevel(entity.Level or 1)
	entity.Level = level
	entity.__ScaledLevel = level

	if level <= 1 then
		-- Always start spawned entities at full health, even when no level multiplier applies.
		entity:SetStat("Health", entity:GetStat("MaxHealth"))
		return
	end

	local healthScaleFactor = LevelScaling.GetHealthScaleFactor(level)
	local damageScaleFactor = LevelScaling.GetDamageScaleFactor(level)

	entity:AddModifier("MaxHealth", Modifier.new("level:maxhealth", "Multiplicative", healthScaleFactor, "level"))

	entity:AddModifier(
		"PhysicalAttack",
		Modifier.new("level:physicalattack", "Multiplicative", damageScaleFactor, "level")
	)

	local defenseBonus = 2 * (level - 1)
	if defenseBonus > 0 then
		entity:AddModifier("Defense", Modifier.new("level:defense", "BaseFlat", defenseBonus, "level"))
	end

	-- Scaling MaxHealth up does not auto-fill Health, so do it explicitly.
	entity:SetStat("Health", entity:GetStat("MaxHealth"))
end

return LevelScaling
