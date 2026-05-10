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
	RadiusTiles = 92,
	BaseY = 120,
	Biome = "TemperateGrassland",
	SeaLevel = 2,
	OceanMode = "None",
} :: WorldConfig

WorldTypes.Profile = {
	Biome = "TemperateGrassland",
	SeaLevel = 2,
	OceanMode = "None",
	StructureSet = { "Tree", "Rock" },
	RadiusRange = { Min = 100, Max = 168 },
	BaseYRange = { Min = 96, Max = 164 },
	TileSizeRange = { Min = 5, Max = 5 },
} :: WorldProfile

WorldTypes.BiomeMaterials = {
	TemperateGrassland = {
		Surface = Enum.Material.Grass,
		Mid = Enum.Material.Ground,
		Deep = Enum.Material.Slate,
		Water = Enum.Material.Water,
	},
	PineHighlands = {
		Surface = Enum.Material.Grass,
		Mid = Enum.Material.Rock,
		Deep = Enum.Material.Slate,
		Water = Enum.Material.Water,
	},
	Forest = {
		Surface = Enum.Material.Grass,
		Mid = Enum.Material.Ground,
		Deep = Enum.Material.Slate,
		Water = Enum.Material.Water,
	},
	DenseForest = {
		Surface = Enum.Material.Grass,
		Mid = Enum.Material.Ground,
		Deep = Enum.Material.Slate,
		Water = Enum.Material.Water,
	},
	Alpine = {
		Surface = Enum.Material.Snow,
		Mid = Enum.Material.Rock,
		Deep = Enum.Material.Slate,
		Water = Enum.Material.Water,
	},
	HighlandDesert = {
		Surface = Enum.Material.Sand,
		Mid = Enum.Material.Sandstone,
		Deep = Enum.Material.Slate,
		Water = Enum.Material.Water,
	},
	Marshland = {
		Surface = Enum.Material.Ground,
		Mid = Enum.Material.Ground,
		Deep = Enum.Material.Slate,
		Water = Enum.Material.Water,
	},
}

return table.freeze(WorldTypes)
