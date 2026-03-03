--!strict

-- Import type from EntityTypes
local EntityTypes = require(script.Parent.EntityTypes)
type Entity = EntityTypes.Entity

-- Require Services
local HttpService = game:GetService("HttpService")

-- Base table
local Entity = {}
Entity.__index = Entity

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
	Model.Name = self.UUID
	self.Character = Model
	self.RootPart = Model.PrimaryPart :: BasePart

	-- Stats
	self.__Stats = {
		Health = 100,
		MaxHealth = 100,
		Defense = 0,
		TrueDefense = 0,
		Resistance = 0,
		Strength = 10,
		CritRate = 0.05,
		CritDamage = 1.5,
		PhysicalAttack = 10,
		MagicalAttack = 10,
		Speed = 8,
	}
	self.__Buffs = {}

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

return Entity
