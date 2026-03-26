--!strict

local HttpService = game:GetService("HttpService")

local Modifier = require(script.Parent.Parent.Modifier.Modifier)
local ModifierType = require(script.Parent.Parent.Modifier.ModifierType)
local StatBlock = require(script.Parent.Parent.Modifier.StatBlock)
local AttackCalculator = require(script.Parent.Parent.Parent.Modules.Combat.AttackCalculator)
local EntityTypes = require(script.Parent.EntityTypes)

type Entity = EntityTypes.Entity
type Stat = EntityTypes.Stat
type ModifierData = EntityTypes.Modifier
type ModifierHandle = EntityTypes.ModifierHandle
type RuntimeStatBlock = EntityTypes.RuntimeStatBlock

local Entity = {}
Entity.__index = Entity

local DEFAULT_STATS: EntityTypes.StatBlock = {
	Health = 100,
	MaxHealth = 100,
	Defense = 0,
	TrueDefense = 0,
	Resistance = 0,
	Strength = 10,
	CritRate = 0.05,
	CritDamage = 1.5,
	Intelligence = 0,
	PhysicalAttack = 10,
	MagicalAttack = 10,
	Speed = 8,
}

local FINALIZE_MAP = {
	Resistance = function(_: string, value: number): number
		return math.clamp(value, 0, 0.9)
	end,
	CritRate = function(_: string, value: number): number
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

function OnStatChanged(self: Entity, statName: string, newValue: number, _: number)
	self.__Stats[statName :: Stat] = newValue

	if statName == "MaxHealth" then
		ClampHealthToMax(self)
	elseif statName == "Health" then
		self.__Alive = newValue > 0
	elseif statName == "Speed" then
		SyncSpeedToCharacter(self)
	end
end

-- Constructor
function Entity.new(Model: Model, Name: string): Entity
	local self = setmetatable({}, Entity)

	self.UUID = HttpService:GenerateGUID(false)
	self.Name = Name
	self.Family = "Unknown"
	self.Level = 1
	self.__ScaledLevel = 1

	self.Character = Model
	self.RootPart = (Model.PrimaryPart or Model:WaitForChild("HumanoidRootPart")) :: BasePart

	-- `__Stats` stays as a plain serializable snapshot of final values.
	-- The real modifier runtime is stored in the module-local RuntimeStats map.
	self.__Stats = table.clone(DEFAULT_STATS)
	self.__Animations = {}
	self.__Buffs = {}
	self.__Components = {
		EquippedIndex = nil,
		ToolbarWeapons = { nil, nil, nil, nil },
	}

	self.__Alive = true
	self.__Brain = nil

	EnsureRuntimeStats((self :: any) :: Entity)
	SyncSpeedToCharacter((self :: any) :: Entity)

	return (self :: any) :: Entity
end

function Entity.Inflate(ent: Entity): Entity
	local uuid = ent.UUID
	local char = workspace.EntitiesFolder:FindFirstChild(uuid)
	if not char then
		error("Entity with UUID " .. uuid .. " does not exist in the world.")
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
		nextValue = math.clamp(to, 0, self:GetStat("MaxHealth"))
	elseif stat == "Resistance" then
		nextValue = math.clamp(to, 0, 0.9)
	end

	local result = EnsureRuntimeStats(self):SetBase(stat, nextValue)
	if stat == "MaxHealth" then
		ClampHealthToMax(self)
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

function Entity.GetStatChangedSignal(self: Entity, stat: Stat)
	return EnsureRuntimeStats(self):GetStatObject(stat).Changed
end

function Entity.IsAlive(self: Entity): boolean
	return self.__Alive
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
	return weapon
end

function Entity.GetToolbarWeapons(self: Entity)
	return self.__Components.ToolbarWeapons
end

function Entity.ApplyDamage(self: Entity, damage: number, target: Entity): ()
	local calculatedDamage = AttackCalculator.Calculate(self, target, damage)
	target:TakeDamage(calculatedDamage, self)
end

function Entity.TakeDamage(self: Entity, damage: number, _: Entity): ()
	if not self:IsAlive() then
		return
	end

	local mitigated = math.max(1, damage - self:GetStat("Defense") - self:GetStat("TrueDefense"))
	local resisted = mitigated * (1 - self:GetStat("Resistance"))
	local finalDamage = math.max(1, math.floor(resisted + 0.5))

	self:SetStat("Health", self:GetStat("Health") - finalDamage)
end

Entity.Modifier = Modifier
Entity.ModifierType = ModifierType

return Entity
