--!strict

local ModifierType = require(script.Parent.ModifierType)
local Signal = require(script.Parent.Signal)
local Stat = require(script.Parent.Stat)

export type Modifier = ModifierType.Modifier
type SignalClass = Signal.Signal
type StatClass = Stat.Stat

export type FinalizeMap = { [string]: (name: string, value: number) -> number }
export type ModifierHandle = {
	Stat: string,
	Id: string,
	Source: string?,
}

export type StatBlock = {
	Changed: SignalClass,
	Get: (self: StatBlock, statName: string) -> number,
	GetBase: (self: StatBlock, statName: string) -> number,
	SetBase: (self: StatBlock, statName: string, value: number) -> number,
	AddModifier: (self: StatBlock, statName: string, modifier: Modifier) -> ModifierHandle,
	RemoveModifier: (self: StatBlock, statName: string, modifierId: string) -> boolean,
	RemoveHandle: (self: StatBlock, handle: ModifierHandle?) -> boolean,
	RemoveAllFromSource: (self: StatBlock, source: string) -> number,
	GetStatObject: (self: StatBlock, statName: string) -> StatClass,
	Destroy: (self: StatBlock) -> (),
}

local StatBlock = {}

local StatBlockMetatable = {}
StatBlockMetatable.__index = function(self, key)
	if StatBlock[key] then
		return StatBlock[key]
	end

	local stats = rawget(self, "_stats")
	local stat = stats and stats[key]
	if stat then
		return stat:GetFinalValue()
	end

	return nil
end

local function CreateStatChangedRelay(self, statName: string, stat: StatClass)
	stat.Changed:Connect(function(newValue, oldValue)
		local onChanged = rawget(self, "_onStatChanged")
		if onChanged then
			onChanged(statName, newValue, oldValue)
		end

		self.Changed:Fire(statName, newValue, oldValue)
	end)
end

function StatBlock.new(baseStats: { [string]: number }, finalizeMap: FinalizeMap?, onStatChanged: ((string, number, number) -> ())?): StatBlock
	local self = setmetatable({}, StatBlockMetatable);
	local selfAny = self :: any

	selfAny._stats = {}
	selfAny._onStatChanged = onStatChanged
	self.Changed = Signal.new()

	for statName, baseValue in pairs(baseStats) do
		local finalize = finalizeMap and finalizeMap[statName] or nil
		local stat = Stat.new(statName, baseValue, finalize);
		selfAny._stats[statName] = stat
		CreateStatChangedRelay(self, statName, stat)
		stat:Recalculate()
	end

	return selfAny :: StatBlock
end

function StatBlock.GetStatObject(self: StatBlock, statName: string): StatClass
	local stats = rawget(self, "_stats") :: { [string]: StatClass }
	local stat = stats[statName]
	assert(stat ~= nil, ("Unknown stat '%s'"):format(statName))
	return stat
end

function StatBlock.Get(self: StatBlock, statName: string): number
	return self:GetStatObject(statName):GetFinalValue()
end

function StatBlock.GetBase(self: StatBlock, statName: string): number
	return self:GetStatObject(statName):GetBaseValue()
end

function StatBlock.SetBase(self: StatBlock, statName: string, value: number): number
	return self:GetStatObject(statName):SetBaseValue(value)
end

function StatBlock.AddModifier(self: StatBlock, statName: string, modifier: Modifier): ModifierHandle
	local id = self:GetStatObject(statName):AddModifier(modifier)
	return {
		Stat = statName,
		Id = id,
		Source = modifier.Source,
	}
end

function StatBlock.RemoveModifier(self: StatBlock, statName: string, modifierId: string): boolean
	return self:GetStatObject(statName):RemoveModifier(modifierId)
end

function StatBlock.RemoveHandle(self: StatBlock, handle: ModifierHandle?): boolean
	if not handle then
		return false
	end

	return self:RemoveModifier(handle.Stat, handle.Id)
end

function StatBlock.RemoveAllFromSource(self: StatBlock, source: string): number
	local total = 0
	local stats = rawget(self, "_stats") :: { [string]: StatClass }
	for _, stat in pairs(stats) do
		total += stat:RemoveAllFromSource(source)
	end

	return total
end

function StatBlock.Destroy(self: StatBlock)
	local stats = rawget(self, "_stats") :: { [string]: StatClass }
	for _, stat in pairs(stats) do
		stat:Destroy()
	end
	self.Changed:Destroy()
end

return StatBlock
