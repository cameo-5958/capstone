--!strict

local CombatNumbers = {}

function CombatNumbers.RoundToTenth(value: number): number
	return math.round(value * 10) / 10
end

function CombatNumbers.FormatTenth(value: number?): string
	if value == nil then
		return "--"
	end

	local rounded = CombatNumbers.RoundToTenth(value)
	if rounded % 1 == 0 then
		return tostring(rounded)
	end

	return tostring(rounded)
end

return table.freeze(CombatNumbers)
