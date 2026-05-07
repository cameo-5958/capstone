--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackContextModule = require(ReplicatedStorage.Classes.Attack.AttackContext)
local EntityType = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)
local EnemyHandler = ReplicatedStorage.Services.Enemy:WaitForChild("EnemyHandler") :: RemoteEvent

type Entity = EntityType.Entity
type AttackContext = AttackContextModule.AttackContext

export type Damage = {
	Build: (from: Entity, to: Entity, baseDamage: number) -> AttackContext,
	CalculateDamageOfEntity: (context: AttackContext) -> number,
	DirectDamageToEntity: (from: Entity, to: Entity, damage: number, context: AttackContext?) -> number,
	TrueDamage: (from: Entity, to: Entity, damage: number, context: AttackContext?) -> number,
}

local Damage = {} :: Damage

local function GetEnemyServiceServer()
	return require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
end

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
		context.DidCrit = false
		return false
	end

	context.DidCrit = true
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

local function PrepareAttackContext(context: AttackContext): boolean
	if not context.To:IsAlive() then
		return false
	end

	context.From:TriggerProcureData(context)
	context.To:TriggerProcureData(context)
	context.From:TriggerApply(context)
	context.To:TriggerOnOncomingHit(context)
	context.From:TriggerOnApplyMultipliers(context)

	context.FinalStats = {
		From = BuildFinalStats(context.Modifiers.From),
		To = BuildFinalStats(context.Modifiers.To),
	}

	return true
end

local function GetDefense(to: Entity, context: AttackContext?): number
	if context then
		local defense = context.FinalStats.To["Defense"]
		if defense ~= nil then
			return defense
		end
	end

	return to:GetStat("Defense")
end

local function ApplyDefense(to: Entity, damage: number, context: AttackContext?): number
	local defense = GetDefense(to, context)
	return damage * (100 / (defense + 100))
end

local function FireDamageIndicator(to: Entity, damage: number, didCrit: boolean?)
	EnemyHandler:FireAllClients("DamageIndicator", {
		UUID = to.UUID,
		Damage = damage,
		IsCrit = didCrit == true,
		CurrentHealth = to:GetStat("Health"),
		MaxHealth = to:GetStat("MaxHealth"),
	})
end

local function ApplyResolvedDamage(from: Entity, to: Entity, damage: number, context: AttackContext?): number
	if not to:IsAlive() then
		return 0
	end

	local finalDamage = CombatNumbers.RoundToTenth(damage)
	local targetWasAlive = to:IsAlive()
	if context then
		from:TriggerOnAttackEnemy(context)
	end

	to:TakeDamage(finalDamage, from)
	FireDamageIndicator(to, finalDamage, context and context.DidCrit)

	if context and context.DoesKnockback and to:IsAlive() then
		GetEnemyServiceServer().RegisterHeavyHit(to, from)
	end

	if context then
		from:TriggerOnHitSuccess(context)

		if targetWasAlive and not to:IsAlive() then
			from:TriggerOnDefeatEnemy(context)
		end
	end

	return finalDamage
end

function Damage.CalculateDamageOfEntity(context: AttackContext): number
	if not PrepareAttackContext(context) then
		return 0
	end

	local damageStatName = GetDamageStatName(context)
	local finalDamage = context.BaseDamage + SumModifiers(context.Modifiers.From.BaseFlat[damageStatName] or {})

	if context.AttackType == "Melee" or context.AttackType == "Ranged" then
		-- Start by mutating the baseDamage with
		-- final base

		-- Increase by strength
		finalDamage *= ((context.FinalStats.From["Strength"] / 100) + 1)

		-- Roll for a crit
		context.DidCrit = false
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

	finalDamage *= (context.FinalStats.From[damageStatName] or 1) * (1 + SumModifiers(
		context.Modifiers.From.Additive[damageStatName] or {}
	)) * ProductModifiers(context.Modifiers.From.Multiplicative[damageStatName] or {})

	return finalDamage
end

function Damage.DirectDamageToEntity(from: Entity, to: Entity, damage: number, context: AttackContext?): number
	if not to:IsAlive() then
		return 0
	end

	return ApplyResolvedDamage(from, to, ApplyDefense(to, damage, context), context)
end

function Damage.TrueDamage(from: Entity, to: Entity, damage: number, context: AttackContext?): number
	if not to:IsAlive() then
		return 0
	end

	return ApplyResolvedDamage(from, to, damage, context)
end

local function ApplyDamage(context: AttackContext)
	local calculatedDamage = Damage.CalculateDamageOfEntity(context)
	Damage.DirectDamageToEntity(context.From, context.To, calculatedDamage, context)
end

function Damage.Build(from: Entity, to: Entity, baseDamage: number): AttackContext
	local context = AttackContextModule.new(from, to)
	context.BaseDamage = baseDamage

	context.Attack = function(self: AttackContext)
		ApplyDamage(self)
	end

	return context
end

return Damage
