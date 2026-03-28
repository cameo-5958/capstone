--!strict

local ModifierType = require(script.Parent.ModifierType)
local Signal = require(script.Parent.Signal)

export type Modifier = ModifierType.Modifier
export type ModifierKind = ModifierType.ModifierKind
type SignalClass = Signal.Signal

export type ModifierBucket = { [string]: Modifier }
export type FinalizeCallback = (name: string, value: number) -> number

export type Stat = {
	Name: string,
	BaseValue: number,
	Dirty: boolean,
	CachedFinalValue: number,
	Changed: SignalClass,
	Finalize: FinalizeCallback?,
	Modifiers: {
		BaseFlat: ModifierBucket,
		BaseAdditive: ModifierBucket,
		FinalAdditive: ModifierBucket,
		Multiplicative: ModifierBucket,
		FinalFlat: ModifierBucket,
	},
	SetBaseValue: (self: Stat, value: number) -> number,
	GetBaseValue: (self: Stat) -> number,
	AddModifier: (self: Stat, modifier: Modifier) -> string,
	RemoveModifier: (self: Stat, modifierId: string) -> boolean,
	RemoveAllFromSource: (self: Stat, source: string) -> number,
	GetFinalValue: (self: Stat) -> number,
	Recalculate: (self: Stat) -> number,
	Destroy: (self: Stat) -> (),
}

local Stat = {}
Stat.__index = Stat

local function SumBucket(bucket: ModifierBucket): number
	local total = 0
	for _, modifier in pairs(bucket) do
		total += modifier.Value
	end

	return total
end

local function ProductBucket(bucket: ModifierBucket): number
	local total = 1
	for _, modifier in pairs(bucket) do
		total *= modifier.Value
	end

	return total
end

local function ComputeFinalValue(self: Stat): number
	local base = self.BaseValue
	local baseFlat = SumBucket(self.Modifiers.BaseFlat)
	local baseAdditive = 1 + SumBucket(self.Modifiers.BaseAdditive)
	local finalAdditive = 1 + SumBucket(self.Modifiers.FinalAdditive)
	local multiplicative = ProductBucket(self.Modifiers.Multiplicative)
	local finalFlat = SumBucket(self.Modifiers.FinalFlat)

	local result = ((base + baseFlat) * baseAdditive * finalAdditive * multiplicative) + finalFlat
	if self.Finalize then
		result = self.Finalize(self.Name, result)
	end

	return result
end

function Stat.new(name: string, baseValue: number, finalize: FinalizeCallback?): Stat
	local self = setmetatable({}, Stat)

	self.Name = name
	self.BaseValue = baseValue
	self.Dirty = true
	self.CachedFinalValue = baseValue
	self.Changed = Signal.new()
	self.Finalize = finalize
	self.Modifiers = {
		BaseFlat = {},
		BaseAdditive = {},
		FinalAdditive = {},
		Multiplicative = {},
		FinalFlat = {},
	}

	return (self :: any) :: Stat
end

function Stat.SetBaseValue(self: Stat, value: number): number
	if self.BaseValue == value then
		return self:GetFinalValue()
	end

	self.BaseValue = value
	self.Dirty = true
	return self:Recalculate()
end

function Stat.GetBaseValue(self: Stat): number
	return self.BaseValue
end

function Stat.AddModifier(self: Stat, modifier: Modifier): string
	local bucket = self.Modifiers[modifier.Type]
	assert(bucket ~= nil, ("Unknown modifier type '%s'"):format(tostring(modifier.Type)))

	bucket[modifier.Id] = modifier
	self.Dirty = true
	self:Recalculate()
	return modifier.Id
end

function Stat.RemoveModifier(self: Stat, modifierId: string): boolean
	for _, bucket in pairs(self.Modifiers) do
		if bucket[modifierId] ~= nil then
			bucket[modifierId] = nil
			self.Dirty = true
			self:Recalculate()
			return true
		end
	end

	return false
end

function Stat.RemoveAllFromSource(self: Stat, source: string): number
	local removed = 0
	for _, bucket in pairs(self.Modifiers) do
		for id, modifier in pairs(bucket) do
			if modifier.Source == source then
				bucket[id] = nil
				removed += 1
			end
		end
	end

	if removed > 0 then
		self.Dirty = true
		self:Recalculate()
	end

	return removed
end

function Stat.Recalculate(self: Stat): number
	if not self.Dirty then
		return self.CachedFinalValue
	end

	local oldValue = self.CachedFinalValue
	local newValue = ComputeFinalValue(self)
	self.CachedFinalValue = newValue
	self.Dirty = false

	if oldValue ~= newValue then
		self.Changed:Fire(newValue, oldValue, self.Name)
	end

	return newValue
end

function Stat.GetFinalValue(self: Stat): number
	if self.Dirty then
		return self:Recalculate()
	end

	return self.CachedFinalValue
end

function Stat.Destroy(self: Stat)
	self.Changed:Destroy()
	for _, bucket in pairs(self.Modifiers) do
		table.clear(bucket)
	end
end

return Stat
