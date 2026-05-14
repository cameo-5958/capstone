return {
	Id = "GreenWarFlag",
	Name = "Green War Flag",
	Desc = "Places a green banner that reduces incoming damage to 80% while in range.",
	Icon = "rbxassetid://119245437245957",
	MaxStack = 8,
	SpawnWith = 0,
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
			Color = Color3.fromRGB(71, 187, 89),
			Modifiers = {
				{
					Stat = "DamageTakenMultiplier",
					ModifierType = "Multiplicative",
					Value = 0.8,
				},
			},
			Flags = { "AffectOverTime" },
		},
	},
}
