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
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(3.2, 4.2, 4.7),
							["HitboxOffset"] = CFrame.new(0, 0, -2.5)
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 5.8,
							["MaxDashRange"] = 1.65,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.65
						}
					},
					{
						["AnimationId"] = "rbxassetid://130560580139040",
						["PowerScale"] = 0.7,
						["MovementLockedUntil"] = 0.65,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(3.2, 4.2, 4.7),
							["HitboxOffset"] = CFrame.new(0, 0, -2.5)
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 5.95,
							["MaxDashRange"] = 1.7,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.65
						}
					},
					{
						["AnimationId"] = "rbxassetid://71284972890547",
						["PowerScale"] = 0.82,
						["MovementLockedUntil"] = 0.72,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(3.2, 4.2, 4.8),
							["HitboxOffset"] = CFrame.new(0, 0, -2.55)
						},
						["AttackContext"] = {
							["SightRange"] = 33,
							["SwingRange"] = 6.0,
							["MaxDashRange"] = 1.75,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.72
						}
					},
					{
						["AnimationId"] = "rbxassetid://97561150583443",
						["PowerScale"] = 0.96,
						["MovementLockedUntil"] = 0.82,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(3.2, 4.2, 4.85),
							["HitboxOffset"] = CFrame.new(0, 0, -2.6)
						},
						["AttackContext"] = {
							["SightRange"] = 33,
							["SwingRange"] = 6.05,
							["MaxDashRange"] = 1.8,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.82
						}
					},
					{
						["AnimationId"] = "rbxassetid://91014619744040",
						["PowerScale"] = 1.45,
						["MovementLockedUntil"] = 1.4,
						["IsHeavy"] = true,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(3.2, 4.2, 4.9),
							["HitboxOffset"] = CFrame.new(0, 0, -2.6)
						},
						["AttackContext"] = {
							["SightRange"] = 34,
							["SwingRange"] = 6.15,
							["MaxDashRange"] = 1.8,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 1.4
						}
					}
				}
			}
		}
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
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45)
						},
						["AttackContext"] = {
							["SightRange"] = 30,
							["SwingRange"] = 4.9,
							["MaxDashRange"] = 1.9,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.52
						}
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.0,
						["MovementLockedUntil"] = 0.64,
						["IsHeavy"] = true,
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45)
						},
						["AttackContext"] = {
							["SightRange"] = 30,
							["SwingRange"] = 5.05,
							["MaxDashRange"] = 2.0,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.64
						}
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.15,
						["MovementLockedUntil"] = 0.76,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45)
						},
						["AttackContext"] = {
							["SightRange"] = 31,
							["SwingRange"] = 5.2,
							["MaxDashRange"] = 2.05,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.76
						}
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.28,
						["MovementLockedUntil"] = 0.86,
						["IsHeavy"] = true,
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45)
						},
						["AttackContext"] = {
							["SightRange"] = 31,
							["SwingRange"] = 5.3,
							["MaxDashRange"] = 2.1,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 0.86
						}
					},
					{
						["AnimationId"] = "rbxassetid://73590100307670",
						["PowerScale"] = 1.55,
						["MovementLockedUntil"] = 1.02,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
						["AttackProfile"] = {
							["Cooldown"] = 0.8,
							["Recovery"] = 0.3,
							["HitboxSize"] = Vector3.new(9.2, 4.6, 6.8),
							["HitboxOffset"] = CFrame.new(0, 0, -3.45)
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 5.45,
							["MaxDashRange"] = 2.15,
							["LungeDuration"] = 0.08,
							["LockDuration"] = 1.02
						}
					}
				}
			}
		}
	},
	["Spear"] = {
		["ExpireAfter"] = 1.65,
		["DefaultCombo"] = "polearm_chain",
		["Combos"] = {
			["polearm_chain"] = {
				["Id"] = "polearm_chain",
				["Attacks"] = {
					{
						["AnimationId"] = "rbxassetid://139475664738055",
						["PowerScale"] = 0.55,
						["MovementLockedUntil"] = 0.62,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(1.2, 4.1, 9.75),
							["HitboxOffset"] = CFrame.new(0, 0, -5.25)
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 11.25,
							["MaxDashRange"] = 2.35,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.5,
							["ActionLockDuration"] = 1.0,
							["LockDuration"] = 1.5
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.18, ["Duration"] = 0.08 }
						}
					},
					{
						["AnimationId"] = "rbxassetid://120272323117203",
						["PowerScale"] = 0.62,
						["MovementLockedUntil"] = 0.66,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(1.2, 4.1, 9.75),
							["HitboxOffset"] = CFrame.new(0, 0, -5.25)
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 11.4,
							["MaxDashRange"] = 2.35,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.5,
							["ActionLockDuration"] = 1.0,
							["LockDuration"] = 1.5
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.17, ["Duration"] = 0.07 },
							{ ["Delay"] = 0.29, ["Duration"] = 0.08 }
						}
					},
					{
						["AnimationId"] = "rbxassetid://77631012695666",
						["PowerScale"] = 0.7,
						["MovementLockedUntil"] = 0.7,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(1.2, 4.1, 9.75),
							["HitboxOffset"] = CFrame.new(0, 0, -5.25)
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 11.45,
							["MaxDashRange"] = 2.4,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.5,
							["ActionLockDuration"] = 1.0,
							["LockDuration"] = 1.5
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.2, ["Duration"] = 0.08 }
						}
					},
					{
						["AnimationId"] = "rbxassetid://109822730522380",
						["PowerScale"] = 0.82,
						["MovementLockedUntil"] = 0.74,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(1.2, 4.1, 9.75),
							["HitboxOffset"] = CFrame.new(0, 0, -5.25)
						},
						["AttackContext"] = {
							["SightRange"] = 32,
							["SwingRange"] = 11.5,
							["MaxDashRange"] = 2.45,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.5,
							["ActionLockDuration"] = 1.0,
							["LockDuration"] = 1.5
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.18, ["Duration"] = 0.07 },
							{ ["Delay"] = 0.31, ["Duration"] = 0.08 }
						}
					},
					{
						["AnimationId"] = "rbxassetid://132830532945806",
						["PowerScale"] = 0.94,
						["MovementLockedUntil"] = 0.82,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(1.2, 4.1, 9.75),
							["HitboxOffset"] = CFrame.new(0, 0, -5.25)
						},
						["AttackContext"] = {
							["SightRange"] = 33,
							["SwingRange"] = 11.65,
							["MaxDashRange"] = 2.5,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.5,
							["ActionLockDuration"] = 1.0,
							["LockDuration"] = 1.5
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.22, ["Duration"] = 0.08 }
						}
					},
					{
						["AnimationId"] = "rbxassetid://103039946478115",
						["PowerScale"] = 1.3,
						["MovementLockedUntil"] = 1.02,
						["IsHeavy"] = true,
						["DoesKnockback"] = true,
						["AttackProfile"] = {
							["HitboxSize"] = Vector3.new(1.2, 4.1, 9.75),
							["HitboxOffset"] = CFrame.new(0, 0, -5.25)
						},
						["AttackContext"] = {
							["SightRange"] = 33,
							["SwingRange"] = 11.8,
							["MaxDashRange"] = 2.55,
							["LungeDuration"] = 0.08,
							["MovementLockDuration"] = 1.5,
							["ActionLockDuration"] = 1.0,
							["LockDuration"] = 1.5
						},
						["HitWindows"] = {
							{ ["Delay"] = 0.24, ["Duration"] = 0.09 },
							{ ["Delay"] = 0.38, ["Duration"] = 0.1 }
						}
					}
				}
			}
		}
	}
}
