return {
	["Name"] = "Test Sword",
	["Type"] = "Sword",
	["Family"] = "Sword",
	["Rarity"] = "COMMON",

	["BaseDamage"] = 10,
	["__Stats"] = {
		["Strength"] = 2,
		["PhysicalAttack"] = 4,
		["CritDamage"] = 0.2,
	},
	["AttackProfile"] = {
		["HitboxSize"] = Vector3.new(2.6, 4.2, 3.8),
		["HitboxOffset"] = CFrame.new(0, 0, -2.05),
	},
	["Weight"] = 4,
	["AttackContext"] = {
		["MaxDashRange"] = 10,
		["SwingRange"] = 6,
	},
	["WeaponPassive"] = nil,

	-- No need for animations, as those
	-- are linked to the weapon family/type.
	["WeaponAbility"] = nil,
	["RightClickAbility"] = nil,

	["Desc"] = "SWORD_TEST_DESC",
}
