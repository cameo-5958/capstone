--!strict

export type PrefabCategory = "Nature" | "Structure" | "Marker"
export type PrefabBiome =
	"TemperateGrassland"
	| "PineHighlands"
	| "Forest"
	| "DenseForest"
	| "Alpine"
	| "HighlandDesert"
	| "Marshland"
	| "Shared"

export type PrefabBuildContext = {
	Position: Vector3,
	TileSize: number,
	SurfaceY: number?,
	Biome: string?,
	ColumnX: number?,
	ColumnZ: number?,
	Seed: number?,
	NameSuffix: string?,
}

export type EnemySpawnMarkerConfig = {
	Enabled: boolean?,
	EnemyPath: string?,
	PoolId: string?,
	LevelMin: number?,
	LevelMax: number?,
	LevelStep: number?,
	LootTableId: string?,
}

export type TreasureSpawnMarkerConfig = {
	Enabled: boolean?,
	LootTableId: string?,
	PromptActionText: string?,
	PromptObjectText: string?,
}

export type PrefabSpawnMarker = {
	Id: string,
	Type: "Enemy" | "Treasure",
	Offset: Vector3,
	YawDegrees: number?,
	Enemy: EnemySpawnMarkerConfig?,
	Treasure: TreasureSpawnMarkerConfig?,
}

export type PrefabDefinition = {
	Id: string,
	Name: string,
	Biome: PrefabBiome,
	Category: PrefabCategory,
	RuntimeEligible: boolean,
	FootprintStuds: Vector2,
	HeightStuds: number,
	SpawnMarkers: { PrefabSpawnMarker }?,
	Build: (parent: Instance, context: PrefabBuildContext) -> Model,
}

return {}
