return {
	["Sword"] = {
		["ExpireAfter"] = 1.5,
		["DefaultCombo"] = "light_chain",
		["Combos"] = {
			["light_chain"] = {
				["Id"] = "light_chain",
				["Attacks"] = {
					-- [1] 0.3s to 0.55s, 80% damage
					{
						["AnimationId"] = "rbxassetid://109172127259985",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(3.2, 4.2, 4.7),
							["HitboxOffset"] = CFrame.new(0, 0, -2.5),
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 5.8,
							["MaxDashRange"] = 1.65,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.65,
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.3, ["Duration"] = 0.25 },
						},
					},
					-- [2] 0.25s to 0.45s, 60% damage
					{
						["AnimationId"] = "rbxassetid://130560580139040",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(3.2, 4.2, 4.7),
							["HitboxOffset"] = CFrame.new(0, 0, -2.5),
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 5.95,
							["MaxDashRange"] = 1.7,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.65,
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.25, ["Duration"] = 0.20 },
						},
					},
					-- [3] 0.2s to 0.45s, 120% damage
					{
						["AnimationId"] = "rbxassetid://91014619744040",
						["IsHeavy"] = true,
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.7,
						["DoesKnockback"] = true,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(3.2, 4.2, 4.8),
							["HitboxOffset"] = CFrame.new(0, 0, -2.55),
						},
						["AttackContext"] = {
							["SightRange"] = 33,
							["SwingRange"] = 6.0,
							["MaxDashRange"] = 1.75,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.72,
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.2, ["Duration"] = 0.25 },
						},
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
						["AnimationId"] = "rbxassetid://133775699616081",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45),
						},
						["AttackContext"] = {
							["SightRange"] = 30,
							["SwingRange"] = 4.9,
							["MaxDashRange"] = 1.9,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.52,
						},
					},
					{
						["AnimationId"] = "rbxassetid://83484538358608",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["IsHeavy"] = true,
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45),
						},
						["AttackContext"] = {
							["SightRange"] = 30,
							["SwingRange"] = 5.05,
							["MaxDashRange"] = 2.0,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.64,
						},
					},
					{
						["AnimationId"] = "rbxassetid://133918469702254",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45),
						},
						["AttackContext"] = {
							["SightRange"] = 31,
							["SwingRange"] = 5.2,
							["MaxDashRange"] = 2.05,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.76,
						},
					},
					{
						["AnimationId"] = "rbxassetid://112592869773047",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.7,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45),
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 5.45,
							["MaxDashRange"] = 2.15,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 1.02,
						},
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
					-- [1] Slim, far thrust — 0.3s to 0.5s, 60% damage
					{
						["AnimationId"] = "rbxassetid://139475664738055",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(0.7, 3.2, 11.5),
							["HitboxOffset"] = CFrame.new(0, 0, -6.25),
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 11.25,
							["MaxDashRange"] = 2.35,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.2,
							["ActionLockDuration"] = 0.7,
							["LockDuration"] = 1.2,
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.3, ["Duration"] = 0.2 },
						},
					},
					-- [2] Two sweeps — 0.25–0.55 (shorter sweep, 12%) and 0.80–1.05 (sweep, 24%)
					-- Note: PowerScale is per-attack; 0.18 averages the two intended values
					{
						["AnimationId"] = "rbxassetid://120272323117203",
						["PowerScale"] = 0.5,
						["MovementLockedUntil"] = 1.7,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(1.2, 4.1, 9.75),
							["HitboxOffset"] = CFrame.new(0, 0, -5.25),
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 11.4,
							["MaxDashRange"] = 2.35,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.7,
							["ActionLockDuration"] = 1.2,
							["LockDuration"] = 1.7,
						},
						["HitWindows"] = {
							{
								["Delay"] = 0.25,
								["Duration"] = 0.30,
								["AttackProfile"] = {
									["HitboxSize"] = Vector3.new(10.0, 4.5, 10.0),
									["HitboxOffset"] = CFrame.new(0, 0, 0),
								},
							},
							{
								["Delay"] = 0.80,
								["Duration"] = 0.25,
								["AttackProfile"] = {
									["HitboxSize"] = Vector3.new(10.0, 4.5, 10.0),
									["HitboxOffset"] = CFrame.new(0, 0, 0),
								},
							},
						},
					},
					-- [3] 360° sweep — 0.35s to 0.5s, 35% damage
					{
						["AnimationId"] = "rbxassetid://77631012695666",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(10.0, 4.5, 10.0),
							["HitboxOffset"] = CFrame.new(0, 0, 0),
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 11.45,
							["MaxDashRange"] = 2.4,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.2,
							["ActionLockDuration"] = 0.7,
							["LockDuration"] = 1.2,
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.35, ["Duration"] = 0.15 },
						},
					},
					-- [4] Full 360° sweep — 0.3s to 0.65s, 15% damage
					{
						["AnimationId"] = "rbxassetid://109822730522380",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(10.0, 4.5, 10.0),
							["HitboxOffset"] = CFrame.new(0, 0, 0),
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 11.5,
							["MaxDashRange"] = 2.45,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.2,
							["ActionLockDuration"] = 0.7,
							["LockDuration"] = 1.2,
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.3, ["Duration"] = 0.35 },
						},
					},
					-- [5] Standard — 0.3s to 0.55s, 35% damage
					{
						["AnimationId"] = "rbxassetid://132830532945806",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.2,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(1.2, 4.1, 9.75),
							["HitboxOffset"] = CFrame.new(0, 0, -5.25),
						},
						["AttackContext"] = {
							["SightRange"] = 33,
							["SwingRange"] = 11.65,
							["MaxDashRange"] = 2.5,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.2,
							["ActionLockDuration"] = 0.7,
							["LockDuration"] = 1.2,
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.3, ["Duration"] = 0.25 },
						},
					},
					-- [6] Slim, far-reaching finisher — 0.25s to 0.5s, 90% damage
					{
						["AnimationId"] = "rbxassetid://103039946478115",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 1.7,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(0.6, 3.0, 14.0),
							["HitboxOffset"] = CFrame.new(0, 0, -7.5),
						},
						["AttackContext"] = {
							["SightRange"] = 33,
							["SwingRange"] = 11.8,
							["MaxDashRange"] = 2.55,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.7,
							["ActionLockDuration"] = 1.2,
							["LockDuration"] = 1.7,
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.25, ["Duration"] = 0.25 },
						},
					},
				},
			},
		},
	},
}
