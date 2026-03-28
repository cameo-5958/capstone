--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackContextModule = require(ReplicatedStorage.Classes.Attack.AttackContext)
local EntityType = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityType.Entity
type AttackContext = AttackContextModule.AttackContext

export type Damage = {
	Build: (from: Entity, to: Entity, baseDamage: number) -> AttackContext,
}

local Damage = {} :: Damage

local function SumModifiers(modifiers): number
	local total = 0
	for _, modifier in pairs(modifiers) do
		total += modifier.Value
	end

	return total
end

local function ProductModifiers(modifiers): number
	local total = 1
	for _, modifier in pairs(modifiers) do
		total *= modifier.Value
	end

	return total
end

local function BuildFinalStats(bucket): { [string]: number }
	local finalStats: { [string]: number } = {}
	local statNames: { [string]: boolean } = {}

	for statName in pairs(bucket.Base) do
		statNames[statName] = true
	end
	for statName in pairs(bucket.BaseFlat) do
		statNames[statName] = true
	end
	for statName in pairs(bucket.Additive) do
		statNames[statName] = true
	end
	for statName in pairs(bucket.Multiplicative) do
		statNames[statName] = true
	end
	for statName in pairs(bucket.FinalFlat) do
		statNames[statName] = true
	end

	for statName in pairs(statNames) do
		local baseValue = bucket.Base[statName] or 0
		local baseFlatValue = SumModifiers(bucket.BaseFlat[statName] or {})
		local additiveValue = 1 + SumModifiers(bucket.Additive[statName] or {})
		local multiplicativeValue = ProductModifiers(bucket.Multiplicative[statName] or {})
		local finalFlatValue = SumModifiers(bucket.FinalFlat[statName] or {})
		finalStats[statName] = ((baseValue + baseFlatValue) * additiveValue * multiplicativeValue) + finalFlatValue
	end

	return finalStats
end

local function GetDamageStatName(context: AttackContext): string
	if context.AttackType == "Magic" then
		return "MagicDamage"
	end

	return "PhysicalDamage"
end

local function CritRoll(context: AttackContext, critChance: number): boolean
	if math.random() >= critChance then
		return false
	end

	context.From:TriggerOnCritRoll(context)
	return true
end

local function TriggerTypedDamageHooks(context: AttackContext)
	if context.AttackType == "Melee" then
		context.From:TriggerOnGiveMelee(context)
		context.To:TriggerOnRecieveMelee(context)
	elseif context.AttackType == "Ranged" then
		context.From:TriggerOnGiveRanged(context)
		context.To:TriggerOnRecieveRanged(context)
	elseif context.AttackType == "Magic" then
		context.From:TriggerOnGiveMagic(context)
		context.To:TriggerOnRecieveMagic(context)
	end
end

local function ApplyDamage(context: AttackContext, baseDamage: number)
	context.From:TriggerProcureData(context)
	context.To:TriggerProcureData(context)
	context.From:TriggerApply(context)
	context.To:TriggerOnOncomingHit(context)
	context.From:TriggerOnApplyMultipliers(context)

	context.FinalStats = {
		From = BuildFinalStats(context.Modifiers.From),
		To = BuildFinalStats(context.Modifiers.To),
	}

	local damageStatName = GetDamageStatName(context)
	local finalDamage = context.BaseDamage + SumModifiers(context.Modifiers.From.BaseFlat[damageStatName] or {})

	if context.AttackType == "Melee" or context.AttackType == "Ranged" then
		-- Start by mutating the baseDamage with
		-- final base

		-- Increase by strength
		finalDamage *= ((context.FinalStats.From["Strength"] / 100) + 1)

		-- Roll for a crit
		if CritRoll(context, context.FinalStats.From["CritRate"]) then
			-- Increase by crit damage
			finalDamage *= ((context.FinalStats.From["CritDamage"] / 100) + 1)
		end

		TriggerTypedDamageHooks(context)
	elseif context.AttackType == "Magic" then
		-- This one is way easier:
		-- - Generate multiplier from intelligence
		-- - Roll Crit Damage

		TriggerTypedDamageHooks(context)
	end

	finalDamage *= context.FinalStats.From[damageStatName] * (1 + SumModifiers(
		context.Modifiers.From.Additive[damageStatName] or {}
	)) * ProductModifiers(context.Modifiers.From.Multiplicative[damageStatName] or {})

	-- Reduce the damage by the defense of the target enemy
	finalDamage *= 100 / (context.FinalStats.To["Defense"] + 100)
	finalDamage = math.round(finalDamage * 100) / 100

	-- Have the entity take the damage
	local targetWasAlive = context.To:IsAlive()
	context.From:TriggerOnAttackEnemy(context)
	context.To:TakeDamage(finalDamage, context.From)
	context.From:TriggerOnHitSuccess(context)

	if targetWasAlive and not context.To:IsAlive() then
		context.From:TriggerOnDefeatEnemy(context)
	end
end

function Damage.Build(from: Entity, to: Entity, baseDamage: number): AttackContext
	local context = AttackContextModule.new(from, to)
	context.BaseDamage = baseDamage

	context.Attack = function(self: AttackContext)
		ApplyDamage(self, baseDamage)
	end

	return context
end

return Damage
