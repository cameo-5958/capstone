--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modifier = require(script.Parent.Parent.Modifier.Modifier)
local ModifierType = require(script.Parent.Parent.Modifier.ModifierType)
local Damage = require(ReplicatedStorage.Classes.Attack.Damage)
local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)
local StatBlock = require(script.Parent.Parent.Modifier.StatBlock)
local EntityTypes = require(script.Parent.EntityTypes)

type Entity = EntityTypes.Entity
type Stat = EntityTypes.Stat
type ModifierData = EntityTypes.Modifier
type ModifierHandle = EntityTypes.ModifierHandle
type RuntimeStatBlock = EntityTypes.RuntimeStatBlock
type AttackModifierApplier = EntityTypes.AttackModifierApplier
type AttackModifierHookName = EntityTypes.AttackModifierHookName

local Entity = {}
Entity.__index = Entity

local DEFAULT_STATS: EntityTypes.StatBlock = {
	Health = 100,
	MaxHealth = 100,
	Mana = 100,
	MaxMana = 100,
	Stamina = 100,
	MaxStamina = 100,
	Defense = 0,
	Strength = 10,
	CritRate = 0.05,
	CritDamage = 1.5,
	Intelligence = 0,
	ManaRegen = 1,
	StaminaRegen = 1,
	ManaConsumptionRate = 1,
	StaminaConsumptionRate = 1,
	ArrowTravelDistance = 1,
	PhysicalAttack = 10,
	MagicalAttack = 10,
	PhysicalDamage = 1,
	MagicDamage = 1,
	DamageTakenMultiplier = 1,
	Speed = 6,
}

local function RoundHealthOrDamageStat(_: string, value: number): number
	return CombatNumbers.RoundToTenth(value)
end

local FINALIZE_MAP = {
	Health = RoundHealthOrDamageStat,
	MaxHealth = RoundHealthOrDamageStat,
	PhysicalAttack = RoundHealthOrDamageStat,
	MagicalAttack = RoundHealthOrDamageStat,
	PhysicalDamage = RoundHealthOrDamageStat,
	MagicDamage = RoundHealthOrDamageStat,
	CritRate = function(_: string, value: number): number
		return math.max(0, value)
	end,
	DamageTakenMultiplier = function(_: string, value: number): number
		return math.max(0, value)
	end,
} :: { [string]: (string, number) -> number }

local RuntimeStats = setmetatable({}, { __mode = "k" }) :: { [Entity]: RuntimeStatBlock }
local OnStatChanged: (self: Entity, statName: string, newValue: number, oldValue: number) -> ()

local function ClampHealthToMax(self: Entity)
	local stats = RuntimeStats[self]
	if not stats then
		return
	end

	local maxHealth = stats:Get("MaxHealth")
	local currentHealth = stats:GetBase("Health")
	local clampedHealth = math.clamp(currentHealth, 0, maxHealth)
	if currentHealth ~= clampedHealth then
		stats:SetBase("Health", clampedHealth)
	end
end

local function ClampManaToMax(self: Entity)
	local stats = RuntimeStats[self]
	if not stats then
		return
	end

	local maxMana = stats:Get("MaxMana")
	local currentMana = stats:GetBase("Mana")
	local clampedMana = math.clamp(currentMana, 0, maxMana)
	if currentMana ~= clampedMana then
		stats:SetBase("Mana", clampedMana)
	end
end

local function ClampStaminaToMax(self: Entity)
	local stats = RuntimeStats[self]
	if not stats then
		return
	end

	local maxStamina = stats:Get("MaxStamina")
	local currentStamina = stats:GetBase("Stamina")
	local clampedStamina = math.clamp(currentStamina, 0, maxStamina)
	if currentStamina ~= clampedStamina then
		stats:SetBase("Stamina", clampedStamina)
	end
end

local function EnsureRuntimeStats(self: Entity): RuntimeStatBlock
	local stats = RuntimeStats[self]
	if stats then
		return stats
	end

	stats = StatBlock.new(table.clone(self.__Stats), FINALIZE_MAP, function(statName, newValue, oldValue)
		OnStatChanged(self, statName, newValue, oldValue)
	end)
	RuntimeStats[self] = stats
	ClampHealthToMax(self)
	ClampManaToMax(self)
	ClampStaminaToMax(self)
	self.__Alive = stats:Get("Health") > 0

	for statName, value in pairs(self.__Stats) do
		self.__Stats[statName] = value
	end

	return stats
end

local function SyncSpeedToCharacter(self: Entity)
	local character = self.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	local speed = EnsureRuntimeStats(self):Get("Speed")
	humanoid:SetAttribute("EntitySpeed", speed)
	humanoid.WalkSpeed = speed
end

local function TriggerAttackModifierHook(self: Entity, hookName: AttackModifierHookName, attackContext: any)
	for _, applier in ipairs(self.__AttackModifierAppliers) do
		local hook = (applier :: any)[hookName]
		if hook then
			hook(applier, attackContext)
		end
	end
end

function OnStatChanged(self: Entity, statName: string, newValue: number, _: number)
	self.__Stats[statName :: Stat] = newValue

	if statName == "MaxHealth" then
		ClampHealthToMax(self)
	elseif statName == "MaxMana" then
		ClampManaToMax(self)
	elseif statName == "MaxStamina" then
		ClampStaminaToMax(self)
	elseif statName == "Health" then
		self.__Alive = newValue > 0
	elseif statName == "Intelligence" then
		EnsureRuntimeStats(self):SetBase("MaxMana", 100 + newValue)
	elseif statName == "Speed" then
		SyncSpeedToCharacter(self)
	end
end

-- Constructor
function Entity.new(Model: Model, Name: string, initialLevel: number?): Entity
	local self = setmetatable({}, Entity)

	self.UUID = HttpService:GenerateGUID(false)
	self.Name = Name
	self.Family = "Unknown"
	local level = math.max(1, math.floor(initialLevel or 1))
	self.Level = level
	self.__ScaledLevel = level

	self.Character = Model
	self.RootPart = (Model.PrimaryPart or Model:WaitForChild("HumanoidRootPart")) :: BasePart

	-- `__Stats` stays as a plain serializable snapshot of final values.
	-- The real modifier runtime is stored in the module-local RuntimeStats map.
	self.__Stats = table.clone(DEFAULT_STATS)
	self.__Animations = {}
	self.__Buffs = {}
	self.__AttackModifierAppliers = {}
	self.__Components = {
		EquippedIndex = nil,
		ToolbarWeapons = { nil, nil, nil, nil },
		ComboState = {
			WeaponClass = nil,
			ComboId = nil,
			AttackIndex = 1,
			LastAttackAt = 0,
		},
	}

	self.__Alive = true
	self.__InvincibleUntil = 0
	self.__Brain = nil

	EnsureRuntimeStats((self :: any) :: Entity)
	SyncSpeedToCharacter((self :: any) :: Entity)

	return (self :: any) :: Entity
end

function Entity.Inflate(ent: Entity): Entity?
	setmetatable(ent, Entity)

	local uuid = ent.UUID
	local char = workspace.EntitiesFolder:FindFirstChild(uuid)
	if not char then
		return nil
	end

	ent.Character = char :: Model
	ent.RootPart = char.PrimaryPart or char:WaitForChild("HumanoidRootPart") :: BasePart
	EnsureRuntimeStats(ent)
	SyncSpeedToCharacter(ent)

	return ent
end

function Entity.SyncCharacterStats(self: Entity)
	SyncSpeedToCharacter(self)
end

function Entity.GetStat(self: Entity, stat: Stat): number
	return EnsureRuntimeStats(self):Get(stat)
end

function Entity.GetBaseStat(self: Entity, stat: Stat): number
	return EnsureRuntimeStats(self):GetBase(stat)
end

function Entity.SetStat(self: Entity, stat: Stat, to: number): number
	local nextValue = to
	if stat == "Health" then
		nextValue = CombatNumbers.RoundToTenth(math.clamp(to, 0, self:GetStat("MaxHealth")))
	elseif stat == "MaxHealth" then
		nextValue = CombatNumbers.RoundToTenth(to)
	elseif stat == "Mana" then
		nextValue = math.clamp(to, 0, self:GetStat("MaxMana"))
	elseif stat == "Stamina" then
		nextValue = math.clamp(to, 0, self:GetStat("MaxStamina"))
	end

	local result = EnsureRuntimeStats(self):SetBase(stat, nextValue)
	if stat == "MaxHealth" then
		ClampHealthToMax(self)
	elseif stat == "MaxMana" then
		ClampManaToMax(self)
	elseif stat == "MaxStamina" then
		ClampStaminaToMax(self)
	end

	return result
end

function Entity.ModifyStat(self: Entity, stat: Stat, delta: number): number
	return self:SetStat(stat, self:GetBaseStat(stat) + delta)
end

--[[
	Primary API for weapons, classes, buffs, and debuffs:

	Weapons:
		local handle = entity:AddModifier("Strength", Modifier.new(
			"weapon:sword_01:strength",
			"BaseFlat",
			5,
			"weapon:sword_01"
		))

	Class passive:
		entity:AddModifier("Speed", Modifier.new(
			"class:rogue:speed",
			"FinalAdditive",
			0.15,
			"class:rogue"
		))

	Temporary buff:
		local hasteHandle = entity:AddModifier("Speed", Modifier.new(
			"buff:haste:123",
			"Multiplicative",
			1.25,
			"buff:haste"
		))
		entity:RemoveModifierHandle(hasteHandle)

	Cleanup by source:
		entity:RemoveModifiersFromSource("weapon:sword_01")
]]
function Entity.AddModifier(self: Entity, stat: Stat, modifier: ModifierData): ModifierHandle
	return EnsureRuntimeStats(self):AddModifier(stat, modifier)
end

function Entity.RemoveModifier(self: Entity, stat: Stat, modifierId: string): boolean
	return EnsureRuntimeStats(self):RemoveModifier(stat, modifierId)
end

function Entity.RemoveModifierHandle(self: Entity, handle: ModifierHandle?): boolean
	return EnsureRuntimeStats(self):RemoveHandle(handle)
end

function Entity.RemoveModifiersFromSource(self: Entity, source: string): number
	self.__Buffs[source] = nil
	return EnsureRuntimeStats(self):RemoveAllFromSource(source)
end

function Entity.RegisterBuffHandles(self: Entity, source: string, handles: { ModifierHandle })
	self.__Buffs[source] = handles
end

function Entity.ClearBuffSource(self: Entity, source: string): number
	local handles = self.__Buffs[source]
	self.__Buffs[source] = nil
	if not handles then
		return 0
	end

	local removed = 0
	for _, handle in ipairs(handles) do
		if self:RemoveModifierHandle(handle) then
			removed += 1
		end
	end

	return removed
end

function Entity.AddAttackModifier(self: Entity, modifier: AttackModifierApplier): AttackModifierApplier
	table.insert(self.__AttackModifierAppliers, modifier)
	return modifier
end

function Entity.RemoveAttackModifier(self: Entity, modifier: AttackModifierApplier): boolean
	for index, current in ipairs(self.__AttackModifierAppliers) do
		if current == modifier then
			table.remove(self.__AttackModifierAppliers, index)
			return true
		end
	end

	return false
end

function Entity.RemoveAttackModifierById(self: Entity, modifierId: string): boolean
	for index, current in ipairs(self.__AttackModifierAppliers) do
		if current.Id == modifierId then
			table.remove(self.__AttackModifierAppliers, index)
			return true
		end
	end

	return false
end

function Entity.GetAttackModifiers(self: Entity): { AttackModifierApplier }
	return self.__AttackModifierAppliers
end

function Entity.TriggerAttackModifierHook(self: Entity, hookName: AttackModifierHookName, attackContext: any): ()
	TriggerAttackModifierHook(self, hookName, attackContext)
end

function Entity.AddAttackModifierApplier(self: Entity, applier: AttackModifierApplier): AttackModifierApplier
	return self:AddAttackModifier(applier)
end

function Entity.RemoveAttackModifierApplier(self: Entity, applier: AttackModifierApplier): boolean
	return self:RemoveAttackModifier(applier)
end

function Entity.GetAttackModifierAppliers(self: Entity): { AttackModifierApplier }
	return self:GetAttackModifiers()
end

function Entity.TriggerApply(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("Apply", attackContext)
end

function Entity.TriggerOnApplyMultipliers(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnApplyMultipliers", attackContext)
end

function Entity.TriggerOnCritRoll(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnCritRoll", attackContext)
end

function Entity.TriggerOnGiveMelee(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnGiveMelee", attackContext)
end

function Entity.TriggerOnRecieveMelee(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnRecieveMelee", attackContext)
end

function Entity.TriggerOnGiveRanged(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnGiveRanged", attackContext)
end

function Entity.TriggerOnRecieveRanged(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnRecieveRanged", attackContext)
end

function Entity.TriggerOnGiveMagic(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnGiveMagic", attackContext)
end

function Entity.TriggerOnRecieveMagic(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnRecieveMagic", attackContext)
end

function Entity.TriggerOnAttackEnemy(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnAttackEnemy", attackContext)
end

function Entity.TriggerOnDefeatEnemy(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnDefeatEnemy", attackContext)
end

function Entity.TriggerOnOncomingHit(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnOncomingHit", attackContext)
end

function Entity.TriggerOnShieldBlock(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnShieldBlock", attackContext)
end

function Entity.TriggerProcureData(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("ProcureData", attackContext)
end

function Entity.TriggerOnHitSuccess(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnHitSuccess", attackContext)
end

function Entity.TriggerOnProjectileExpire(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnProjectileExpire", attackContext)
end

function Entity.TriggerOnWeaponSwap(self: Entity, attackContext: any): ()
	self:TriggerAttackModifierHook("OnWeaponSwap", attackContext)
end

function Entity.GetStatsChangedSignal(self: Entity)
	return EnsureRuntimeStats(self).Changed
end

function Entity.GetStatChangedSignal(self: Entity, stat: Stat)
	return EnsureRuntimeStats(self):GetStatObject(stat).Changed
end

function Entity.IsAlive(self: Entity): boolean
	return self.__Alive
end

function Entity.IsInvincible(self: Entity): boolean
	return workspace:GetServerTimeNow() < self.__InvincibleUntil
end

function Entity.SetInvincibleFor(self: Entity, duration: number): number
	local untilTime = workspace:GetServerTimeNow() + math.max(0, duration)
	self.__InvincibleUntil = math.max(self.__InvincibleUntil, untilTime)
	return self.__InvincibleUntil
end

function Entity.ClearInvincibility(self: Entity): ()
	self.__InvincibleUntil = 0
end

function Entity.GetEquippedWeapon(self: Entity)
	local index = self.__Components.EquippedIndex
	if not index then
		return nil
	end

	return self.__Components.ToolbarWeapons[index]
end

function Entity.GetEquippedIndex(self: Entity)
	return self.__Components.EquippedIndex
end

function Entity.SetEquippedIndex(self: Entity, index: number?)
	if index ~= nil and (index < 1 or index > 4) then
		error("Equipped index out of range: " .. tostring(index))
	end

	if self.__Components.EquippedIndex ~= index then
		self:ResetComboState()
	end
	self.__Components.EquippedIndex = index
	return index
end

function Entity.ClearEquippedWeapon(self: Entity)
	local equipped = self:GetEquippedWeapon()
	self.__Components.EquippedIndex = nil
	return equipped
end

function Entity.GetToolbarWeapon(self: Entity, slot: number)
	return self.__Components.ToolbarWeapons[slot]
end

function Entity.SetToolbarWeapon(self: Entity, slot: number, weapon: any)
	if slot < 1 or slot > 4 then
		error("Toolbar slot out of range: " .. tostring(slot))
	end

	self.__Components.ToolbarWeapons[slot] = weapon
	if self.__Components.EquippedIndex == slot then
		self:ResetComboState()
	end
	return weapon
end

function Entity.GetToolbarWeapons(self: Entity)
	return self.__Components.ToolbarWeapons
end

function Entity.ResetComboState(self: Entity): ()
	self.__Components.ComboState.WeaponClass = nil
	self.__Components.ComboState.ComboId = nil
	self.__Components.ComboState.AttackIndex = 1
	self.__Components.ComboState.LastAttackAt = 0
end

function Entity.ApplyDamage(self: Entity, damage: number, target: Entity): ()
	local context = Damage.Build(self, target, damage)
	context:Attack()
end

function Entity.DirectDamageToEntity(self: Entity, damage: number, target: Entity): ()
	Damage.DirectDamageToEntity(self, target, damage)
end

function Entity.TrueDamage(self: Entity, damage: number, target: Entity): ()
	Damage.TrueDamage(self, target, damage)
end

function Entity.TakeDamage(self: Entity, damage: number, _: Entity): ()
	local roundedDamage = CombatNumbers.RoundToTenth(damage)
	self:SetStat("Health", self:GetStat("Health") - roundedDamage)
end

Entity.Modifier = Modifier
Entity.ModifierType = ModifierType

return Entity
