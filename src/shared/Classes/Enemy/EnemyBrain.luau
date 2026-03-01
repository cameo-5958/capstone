--!strict
-- EnemyBrain.luau defines the logic that
-- brains use

local Brain = {}
Brain.__index = Brain

-- Typing
type Brain = typeof(setmetatable(
	{
		-- The brain has many different attributes
		-- that are associated with it
	} :: any,
	Brain
))

return Brain
