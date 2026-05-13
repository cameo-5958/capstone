return {
	Id = "RedWarFlag",
	Name = "Red War Flag",
	Desc = "Places a red banner that heals nearby allies for 1% every 0.5 seconds.",
	Icon = "rbxassetid://134706181541710",
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
			HealPercentPerTick = 0.01,
			Color = Color3.fromRGB(214, 62, 62),
			Flags = { "AffectOverTime" },
		},
	},
}
