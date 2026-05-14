return {
	Id = "BlueWarFlag",
	Name = "Blue War Flag",
	Desc = "Places a blue banner that increases outgoing damage by 25% while in range.",
	Icon = "rbxassetid://127995668919892",
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
			Color = Color3.fromRGB(72, 133, 232),
			Modifiers = {
				{
					Stat = "PhysicalDamage",
					ModifierType = "Multiplicative",
					Value = 1.25,
				},
				{
					Stat = "MagicDamage",
					ModifierType = "Multiplicative",
					Value = 1.25,
				},
			},
			Flags = { "AffectOverTime" },
		},
	},
}
