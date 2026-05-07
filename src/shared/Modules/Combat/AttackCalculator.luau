--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatNumbers = require(ReplicatedStorage.Modules.Combat.CombatNumbers)

local AttackCalculator = {}

function AttackCalculator.Calculate(attacker, target, baseDamage: number)
	local damage = CombatNumbers.RoundToTenth(baseDamage)
	print(("Temporary attack calculation: %s -> %s | baseDamage=%.1f"):format(attacker.Name, target.Name, damage))
	return damage
end

return table.freeze(AttackCalculator)
