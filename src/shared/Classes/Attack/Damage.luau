--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackContextModule = require(ReplicatedStorage.Classes.Attack.AttackContext)
local EntityType = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityType.Entity
type AttackContext = AttackContextModule.AttackContext

export type Damage = {
	Build: (from: Entity, to: Entity, baseDamage: number) -> AttackContext,
}

local Damage = {} :: Damage

local function ApplyDamage(context: AttackContext, baseDamage: number)
	local finalDamage = baseDamage

	if context.AttackType == "Melee" then
		-- TODO: Calculate melee damage
	elseif context.AttackType == "Ranged" then
		-- TODO: Calculate ranged damage
	elseif context.AttackType == "Magic" then
		-- TODO: Calculate magic damage
	end

	-- TODO: Trigger attack hooks

	context.To:TakeDamage(finalDamage, context.From)
end

function Damage.Build(from: Entity, to: Entity, baseDamage: number): AttackContext
	local context = AttackContextModule.new(from, to)

	context.Attack = function(self: AttackContext)
		ApplyDamage(self, baseDamage)
	end

	return context
end

return Damage
