--!strict

-- Import type from EntityTypes
local EntityTypes = require(script.Parent.EntityTypes)
type Entity = EntityTypes.Entity

-- Require Services
local HttpService = game:GetService("HttpService")

-- Base table
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

-- Constructor
function Entity.new(Model: Model, Name: string): Entity
	local self = setmetatable({}, Entity)

	-- Base Metadata
	self.UUID = HttpService:GenerateGUID(false)
	self.Name = Name
	self.Family = "Unknown"
	self.Level = 1
	self.__ScaledLevel = 1

	-- Models
	self.Character = Model
	self.RootPart = (Model.PrimaryPart or Model:WaitForChild("HumanoidRootPart")) :: BasePart

	-- Stats
	self.__Stats = table.clone(DEFAULT_STATS)
	self.__Animations = {}
	self.__Buffs = {}
	self.__Components = {
		EquippedIndex = nil,
		ToolbarWeapons = { nil, nil, nil, nil },
	}

	-- States
	self.__Alive = true

	-- Brain (only for enemies)
	self.__Brain = nil

	return (self :: any) :: Entity
end

-- Inflate the Entity class given an UUID
function Entity.Inflate(ent: Entity): Entity
	-- Grab UUID from the folder
	local uuid = ent.UUID
	local char = workspace.EntitiesFolder:FindFirstChild(uuid)
	if not char then
		error("Entity with UUID " .. uuid .. " does not exist in the world.")
	end

	-- Inflate self
	ent.Character = char :: Model
	ent.RootPart = char.PrimaryPart or char:WaitForChild("HumanoidRootPart") :: BasePart

	return ent
end

function Entity.GetStat(self: Entity, stat: EntityTypes.Stat): number
	return self.__Stats[stat] or 0
end

function Entity.SetStat(self: Entity, stat: EntityTypes.Stat, to: number): number
	local nextValue = to

	if stat == "Health" then
		nextValue = math.clamp(to, 0, self:GetStat("MaxHealth"))
	elseif stat == "Resistance" then
		nextValue = math.clamp(to, 0, 0.9)
	end

	self.__Stats[stat] = nextValue

	if stat == "MaxHealth" then
		self.__Stats.Health = math.clamp(self.__Stats.Health, 0, nextValue)
	end

	if stat == "Health" then
		self.__Alive = nextValue > 0
	end

	return nextValue
end

function Entity.ModifyStat(self: Entity, stat: EntityTypes.Stat, delta: number): number
	return self:SetStat(stat, self:GetStat(stat) + delta)
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
	target:TakeDamage(damage, self)
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

return Entity
