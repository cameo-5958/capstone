return {
	["Sword"] = {
		["ExpireAfter"] = 1.5,
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
		["ExpireAfter"] = 1.5,
		["DefaultCombo"] = "heavy_chain",
		["Combos"] = {
			["heavy_chain"] = {
				["Id"] = "heavy_chain",
				["Attacks"] = {
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 0.85,
						["MovementLockedUntil"] = 0.52,
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 0.64,
						["IsHeavy"] = true,
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.15,
						["MovementLockedUntil"] = 0.76,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.28,
						["MovementLockedUntil"] = 0.86,
						["IsHeavy"] = true,
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.55,
						["MovementLockedUntil"] = 1.02,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
					},
				},
			},
		},
	},
	["Spear"] = {
		["ExpireAfter"] = 1.65,
		["DefaultCombo"] = "polearm_chain",
		["Combos"] = {
			["polearm_chain"] = {
				["Id"] = "polearm_chain",
				["Attacks"] = {
					{
						["AnimationId"] = "",
						["PowerScale"] = 0.55,
						["MovementLockedUntil"] = 0.62,
						["HitWindows"] = {
							{ ["Delay"] = 0.18, ["Duration"] = 0.08 },
						},
					},
					{
						["AnimationId"] = "",
						["PowerScale"] = 0.62,
						["MovementLockedUntil"] = 0.66,
						["HitWindows"] = {
							{ ["Delay"] = 0.17, ["Duration"] = 0.07 },
							{ ["Delay"] = 0.29, ["Duration"] = 0.08 },
						},
					},
					{
						["AnimationId"] = "",
						["PowerScale"] = 0.7,
						["MovementLockedUntil"] = 0.7,
						["HitWindows"] = {
							{ ["Delay"] = 0.2, ["Duration"] = 0.08 },
						},
					},
					{
						["AnimationId"] = "",
						["PowerScale"] = 0.82,
						["MovementLockedUntil"] = 0.74,
						["HitWindows"] = {
							{ ["Delay"] = 0.18, ["Duration"] = 0.07 },
							{ ["Delay"] = 0.31, ["Duration"] = 0.08 },
						},
					},
					{
						["AnimationId"] = "",
						["PowerScale"] = 0.94,
						["MovementLockedUntil"] = 0.82,
						["HitWindows"] = {
							{ ["Delay"] = 0.22, ["Duration"] = 0.08 },
						},
					},
					{
						["AnimationId"] = "",
						["PowerScale"] = 1.3,
						["MovementLockedUntil"] = 1.02,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
						["HitWindows"] = {
							{ ["Delay"] = 0.24, ["Duration"] = 0.09 },
							{ ["Delay"] = 0.38, ["Duration"] = 0.1 },
						},
					},
				},
			},
		},
	},
}
