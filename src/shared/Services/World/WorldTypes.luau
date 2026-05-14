--!strict

export type WorldConfig = {
	Seed: number,
	TileSize: number,
	ChunkSize: number,
	RadiusTiles: number,
	BaseY: number,
	Biome: string,
	SeaLevel: number,
	OceanMode: string,
}

export type WorldProfile = {
	Biome: string,
	SeaLevel: number,
	OceanMode: string,
	StructureSet: { string },
	RadiusRange: { Min: number, Max: number },
	BaseYRange: { Min: number, Max: number },
	TileSizeRange: { Min: number, Max: number },
}

export type TileColumn = {
	X: number,
	Z: number,
	Solid: boolean,
	Biome: string,
	IsPath: boolean,
	SurfaceY: number,
	BottomY: number,
	SurfaceMaterial: Enum.Material,
	PathMaterial: Enum.Material?,
	FillMaterial: Enum.Material,
	HasWater: boolean,
	StructureTag: string?,
}

export type TileColumnPayload = {
	X: number,
	Z: number,
	Solid: boolean,
	Biome: string,
	IsPath: boolean,
	SurfaceY: number,
	BottomY: number,
	SurfaceMaterial: string,
	PathMaterial: string?,
	FillMaterial: string,
	HasWater: boolean,
	StructureTag: string?,
}

export type ChunkData = {
	ChunkX: number,
	ChunkZ: number,
	Columns: { TileColumnPayload },
}

local WorldTypes = {}

WorldTypes.DefaultConfig = {
	Seed = 0,
	TileSize = 5,
	ChunkSize = 8,
	RadiusTiles = 138,
	BaseY = 120,
	Biome = "Plains",
	SeaLevel = 2,
	OceanMode = "None",
} :: WorldConfig

WorldTypes.Profile = {
	Biome = "Plains",
	SeaLevel = 2,
	OceanMode = "None",
	StructureSet = { "Tree", "Rock" },
	RadiusRange = { Min = 75, Max = 126 },
	BaseYRange = { Min = 96, Max = 164 },
	TileSizeRange = { Min = 5, Max = 5 },
} :: WorldProfile

WorldTypes.CanonicalBiomes = { "Desert", "Forest", "Mountain", "Plains", "Tundra" }

WorldTypes.BiomeAliases = {
	Desert = "Desert",
	Forest = "Forest",
	Mountain = "Mountain",
	Plains = "Plains",
	Tundra = "Tundra",
	TemperateGrassland = "Plains",
	PineHighlands = "Mountain",
	Alpine = "Tundra",
	HighlandDesert = "Desert",
	Marshland = "Forest",
} :: { [string]: string }

WorldTypes.BiomeMaterials = {
	Plains = {
		Surface = Enum.Material.Grass,
		Mid = Enum.Material.Rock,
		Deep = Enum.Material.Rock,
		Water = Enum.Material.Water,
	},
	Forest = {
		Surface = Enum.Material.Grass,
		Mid = Enum.Material.Rock,
		Deep = Enum.Material.Rock,
		Water = Enum.Material.Water,
	},
	Tundra = {
		Surface = Enum.Material.Snow,
		Mid = Enum.Material.Rock,
		Deep = Enum.Material.Rock,
		Water = Enum.Material.Water,
	},
	Desert = {
		Surface = Enum.Material.Sand,
		Mid = Enum.Material.Rock,
		Deep = Enum.Material.Rock,
		Water = Enum.Material.Water,
	},
	Mountain = {
		Surface = Enum.Material.Rock,
		Mid = Enum.Material.Rock,
		Deep = Enum.Material.Rock,
		Water = Enum.Material.Water,
	},
}

return table.freeze(WorldTypes)
