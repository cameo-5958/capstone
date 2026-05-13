return {
	Id = "BlackWarFlag",
	Name = "Black War Flag",
	Desc = "Places a black banner that grants healing, offense, defense, and speed.",
	Icon = "rbxassetid://103162751130088",
	MaxStack = 8,
	SpawnWith = 2,
	InventoryData = {
		Category = "Banner",
		Type = "Support",
	},
	Effects = {
		{
			Kind = "FlagBoost",
			Duration = 60,
			Radius = 45,
			Range = 8,
			TickRate = 0.5,
			ContactModifierDuration = 1,
			PulseInterval = 1,
			HealPercentPerTick = 0.005,
			Color = Color3.fromRGB(34, 34, 34),
			Modifiers = {
				{
					Stat = "DamageTakenMultiplier",
					ModifierType = "Multiplicative",
					Value = 0.9,
				},
				{
					Stat = "Speed",
					ModifierType = "BaseFlat",
					Value = 1,
				},
				{
					Stat = "PhysicalDamage",
					ModifierType = "Multiplicative",
					Value = 1.5,
				},
				{
					Stat = "MagicDamage",
					ModifierType = "Multiplicative",
					Value = 1.5,
				},
			},
			Flags = { "AffectOverTime" },
		},
	},
}
