return {
	["Sword"] = {
		["ExpireAfter"] = 1.6,
		["DefaultCombo"] = "light_chain",
		["Combos"] = {
			["light_chain"] = {
				["Id"] = "light_chain",
				["Attacks"] = {
					{
						["AnimationId"] = "rbxassetid://109172127259985",
						["PowerScale"] = 0.6,
						["MovementLockedUntil"] = 0.65,
					},
					{
						["AnimationId"] = "rbxassetid://130560580139040",
						["PowerScale"] = 0.7,
						["MovementLockedUntil"] = 0.65,
					},
					{
						["AnimationId"] = "rbxassetid://91014619744040",
						["PowerScale"] = 1.45,
						["MovementLockedUntil"] = 1.4,
						["IsHeavy"] = true,
					},
				},
			},
		},
	},
	["Claymore"] = {
		["ExpireAfter"] = 2.1,
		["DefaultCombo"] = "heavy_chain",
		["Combos"] = {
			["heavy_chain"] = {
				["Id"] = "heavy_chain",
				["Attacks"] = {
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 0.4,
						["IsHeavy"] = true,
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.2,
						["MovementLockedUntil"] = 0.45,
						["IsHeavy"] = true,
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.35,
						["MovementLockedUntil"] = 0.55,
						["IsHeavy"] = true,
					},
				},
			},
		},
	},
}
