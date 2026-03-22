return {
	["Name"] = "Test Sword",
	["Family"] = "Sword",
	["Rarity"] = "COMMON",

	["BaseDamage"] = 10,
	["__Stats"] = {
		-- Empty, but stats would go here
	},
	["AttackContext"] = {
		["MaxDashRange"] = 10,
		["SwingRange"] = 6,
	},

	-- No need for Animations, as those
	-- are linked to the "Family"
	["RightClickAbility"] = nil, --function() end,

	["Desc"] = "SWORD_TEST_DESC",
}
