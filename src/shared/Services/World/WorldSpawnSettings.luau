--!strict

export type WeightedEnemyEntry = {
	EnemyPath: string,
	Weight: number,
}

export type EnemyPool = {
	Entries: { WeightedEnemyEntry },
}

export type BiomeLevelRange = {
	Min: number,
	Max: number,
	Step: number?,
}

export type ChunkLifecycleSettings = {
	Enabled: boolean,
	DespawnEnemiesOnChunkUnload: boolean,
	DespawnTreasureOnChunkUnload: boolean,
}

export type PromptSettings = {
	ActionText: string,
	ObjectText: string,
	HoldDuration: number,
	MaxActivationDistance: number,
	RequiresLineOfSight: boolean,
}

export type StackReward = {
	ItemKind: string,
	StackKey: string,
	Min: number,
	Max: number,
	MaxStack: number?,
	Weight: number?,
	Data: { [string]: any }?,
}

export type WeaponReward = {
	WeaponPath: string,
	Weight: number,
}

export type TreasureLootTable = {
	CurrencyReward: StackReward?,
	StackRewards: { StackReward }?,
	StackRewardRolls: number?,
	WeaponRewards: { WeaponReward }?,
	WeaponRolls: number?,
}

export type EnemySettings = {
	Enabled: boolean,
	DefaultPoolId: string,
	Pools: { [string]: EnemyPool },
	BiomeLevelRanges: { [string]: BiomeLevelRange },
	DefaultLevelRange: BiomeLevelRange,
}

export type TreasureSettings = {
	Enabled: boolean,
	DefaultLootTableId: string,
	DefaultPrompt: PromptSettings,
	LootTables: { [string]: TreasureLootTable },
}

export type DebugSettings = {
	Verbose: boolean,
	ShowSpawnAnchors: boolean,
}

export type WorldSpawnSettings = {
	Enabled: boolean,
	ChunkLifecycle: ChunkLifecycleSettings,
	Enemy: EnemySettings,
	Treasure: TreasureSettings,
	Debug: DebugSettings,
}

local Settings = {
	Enabled = true,

	ChunkLifecycle = {
		Enabled = true,
		DespawnEnemiesOnChunkUnload = true,
		DespawnTreasureOnChunkUnload = true,
	},

	Enemy = {
		Enabled = true,
		DefaultPoolId = "Golem.Default",
		Pools = {
			["Golem.Default"] = {
				Entries = {
					{ EnemyPath = "Golem.Basalt", Weight = 50 },
					{ EnemyPath = "Golem.Granite", Weight = 30 },
					{ EnemyPath = "Golem.Runic", Weight = 20 },
				},
			},
			["Camp.Guards"] = {
				Entries = {
					{ EnemyPath = "Golem.Basalt", Weight = 55 },
					{ EnemyPath = "Golem.Granite", Weight = 30 },
					{ EnemyPath = "Golem.Runic", Weight = 15 },
				},
			},
			["Camp.Elite"] = {
				Entries = {
					{ EnemyPath = "Golem.Granite", Weight = 40 },
					{ EnemyPath = "Golem.Runic", Weight = 60 },
				},
			},
		},
		BiomeLevelRanges = {
			TemperateGrassland = { Min = 5, Max = 20, Step = 5 },
			PineHighlands = { Min = 15, Max = 40, Step = 5 },
			Forest = { Min = 12, Max = 35, Step = 5 },
			DenseForest = { Min = 18, Max = 45, Step = 5 },
			Alpine = { Min = 22, Max = 55, Step = 5 },
			HighlandDesert = { Min = 14, Max = 38, Step = 5 },
			Marshland = { Min = 20, Max = 50, Step = 5 },
		},
		DefaultLevelRange = {
			Min = 10,
			Max = 30,
			Step = 5,
		},
	},

	Treasure = {
		Enabled = true,
		DefaultLootTableId = "FieldCache",
		DefaultPrompt = {
			ActionText = "Claim",
			ObjectText = "Treasure Cache",
			HoldDuration = 0.35,
			MaxActivationDistance = 10,
			RequiresLineOfSight = false,
		},
		LootTables = {
			FieldCache = {
				CurrencyReward = {
					ItemKind = "Currency",
					StackKey = "Gold",
					Min = 14,
					Max = 32,
					MaxStack = 9999,
					Data = {
						DisplayName = "Gold",
					},
				},
				StackRewards = {
					{
						ItemKind = "Material",
						StackKey = "Fiber",
						Min = 1,
						Max = 4,
						MaxStack = 999,
						Weight = 5,
						Data = { DisplayName = "Worn Fiber" },
					},
					{
						ItemKind = "Material",
						StackKey = "Ore",
						Min = 1,
						Max = 3,
						MaxStack = 999,
						Weight = 3,
						Data = { DisplayName = "Crude Ore" },
					},
				},
				StackRewardRolls = 1,
				WeaponRewards = {
					{ WeaponPath = "Damaged.Greatsword", Weight = 3 },
					{ WeaponPath = "Skeletal.Shiv", Weight = 2 },
					{ WeaponPath = "Unbound.LastStrike", Weight = 1 },
				},
				WeaponRolls = 1,
			},
			CampStock = {
				CurrencyReward = {
					ItemKind = "Currency",
					StackKey = "Gold",
					Min = 24,
					Max = 48,
					MaxStack = 9999,
					Data = {
						DisplayName = "Gold",
					},
				},
				StackRewards = {
					{
						ItemKind = "Material",
						StackKey = "Fiber",
						Min = 3,
						Max = 8,
						MaxStack = 999,
						Weight = 5,
						Data = { DisplayName = "Worn Fiber" },
					},
					{
						ItemKind = "Material",
						StackKey = "Ore",
						Min = 2,
						Max = 6,
						MaxStack = 999,
						Weight = 4,
						Data = { DisplayName = "Crude Ore" },
					},
					{
						ItemKind = "Consumable",
						StackKey = "Ration",
						Min = 1,
						Max = 2,
						MaxStack = 30,
						Weight = 2,
						Data = { DisplayName = "Field Ration" },
					},
				},
				StackRewardRolls = 2,
				WeaponRewards = {
					{ WeaponPath = "Damaged.Greatsword", Weight = 3 },
					{ WeaponPath = "Skeletal.Saber", Weight = 2 },
					{ WeaponPath = "Skeletal.Lance", Weight = 1 },
				},
				WeaponRolls = 1,
			},
			RelicCache = {
				CurrencyReward = {
					ItemKind = "Currency",
					StackKey = "Gold",
					Min = 40,
					Max = 90,
					MaxStack = 9999,
					Data = {
						DisplayName = "Gold",
					},
				},
				StackRewards = {
					{
						ItemKind = "Material",
						StackKey = "Ore",
						Min = 4,
						Max = 10,
						MaxStack = 999,
						Weight = 6,
						Data = { DisplayName = "Crude Ore" },
					},
					{
						ItemKind = "Material",
						StackKey = "RelicDust",
						Min = 1,
						Max = 3,
						MaxStack = 200,
						Weight = 3,
						Data = { DisplayName = "Relic Dust" },
					},
				},
				StackRewardRolls = 2,
				WeaponRewards = {
					{ WeaponPath = "Skeletal.Saber", Weight = 3 },
					{ WeaponPath = "Skeletal.Lance", Weight = 3 },
					{ WeaponPath = "Skeletal.Shiv", Weight = 2 },
				},
				WeaponRolls = 1,
			},
		},
	},

	Debug = {
		Verbose = false,
		ShowSpawnAnchors = false,
	},
} :: WorldSpawnSettings

return table.freeze(Settings)
