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

export type PrefabDefinition = {
	Id: string,
	Name: string,
	Biome: PrefabBiome,
	Category: PrefabCategory,
	RuntimeEligible: boolean,
	FootprintStuds: Vector2,
	HeightStuds: number,
	Build: (parent: Instance, context: PrefabBuildContext) -> Model,
}

return {}
