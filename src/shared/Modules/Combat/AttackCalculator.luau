--!strict

local AttackCalculator = {}

function AttackCalculator.Calculate(attacker, target, baseDamage: number)
	print(("Temporary attack calculation: %s -> %s | baseDamage=%.2f"):format(attacker.Name, target.Name, baseDamage))
	return baseDamage
end

return table.freeze(AttackCalculator)
