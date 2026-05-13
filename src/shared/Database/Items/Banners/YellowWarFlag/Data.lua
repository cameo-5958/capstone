return {
	Id = "YellowWarFlag",
	Name = "Yellow War Flag",
	Desc = "Places a yellow banner that grants +2 speed while in range.",
	Icon = "rbxassetid://89774490546710",
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
			Color = Color3.fromRGB(233, 193, 64),
			Modifiers = {
				{
					Stat = "Speed",
					ModifierType = "BaseFlat",
					Value = 2,
				},
			},
			Flags = { "AffectOverTime" },
		},
	},
}
