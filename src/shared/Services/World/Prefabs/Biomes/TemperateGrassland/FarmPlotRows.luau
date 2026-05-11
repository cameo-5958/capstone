--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "TemperateGrassland::FarmPlotRows",
	Name = "FarmPlotRows",
	Biome = "TemperateGrassland",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(20, 16),
	HeightStuds = 7,
	SpawnMarkers = {
		{
			Id = "FarmGuard",
			Type = "Enemy",
			Offset = Vector3.new(0, 0, -5),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 8,
				LevelMax = 24,
				LevelStep = 2,
			},
		},
		{
			Id = "FarmSupplies",
			Type = "Treasure",
			Offset = Vector3.new(6.0, 0, -4.5),
			Treasure = {
				LootTableId = "FieldCache",
				PromptActionText = "Gather Supplies",
				PromptObjectText = "Farm Supplies",
			},
		},
	},
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "PlotBase", pivot * CFrame.new(0, 0.5, 0), Vector3.new(16, 1, 12), Enum.Material.Ground, Color3.fromRGB(122, 95, 67), 0, nil)
	PrefabUtils.addPart(model, "FurrowA", pivot * CFrame.new(0, 0.85, -3.0), Vector3.new(14, 0.7, 1.4), Enum.Material.Ground, Color3.fromRGB(103, 78, 56), 0, nil)
	PrefabUtils.addPart(model, "FurrowB", pivot * CFrame.new(0, 0.85, -0.9), Vector3.new(14, 0.7, 1.4), Enum.Material.Ground, Color3.fromRGB(99, 74, 52), 0, nil)
	PrefabUtils.addPart(model, "FurrowC", pivot * CFrame.new(0, 0.85, 1.2), Vector3.new(14, 0.7, 1.4), Enum.Material.Ground, Color3.fromRGB(103, 78, 56), 0, nil)
	PrefabUtils.addPart(model, "FurrowD", pivot * CFrame.new(0, 0.85, 3.3), Vector3.new(14, 0.7, 1.4), Enum.Material.Ground, Color3.fromRGB(99, 74, 52), 0, nil)

	PrefabUtils.addPart(model, "CropPatchA", pivot * CFrame.new(-4.2, 1.35, -3.0), Vector3.new(2.6, 1.0, 1.1), Enum.Material.Grass, Color3.fromRGB(112, 154, 86), 0, nil)
	PrefabUtils.addPart(model, "CropPatchB", pivot * CFrame.new(3.8, 1.35, -0.9), Vector3.new(2.6, 1.0, 1.1), Enum.Material.Grass, Color3.fromRGB(106, 148, 80), 0, nil)
	PrefabUtils.addPart(model, "CropPatchC", pivot * CFrame.new(-3.5, 1.35, 1.2), Vector3.new(2.6, 1.0, 1.1), Enum.Material.Grass, Color3.fromRGB(108, 151, 83), 0, nil)
	PrefabUtils.addPart(model, "CropPatchD", pivot * CFrame.new(4.3, 1.35, 3.3), Vector3.new(2.6, 1.0, 1.1), Enum.Material.Grass, Color3.fromRGB(114, 156, 86), 0, nil)

	PrefabUtils.addPart(model, "FenceWest", pivot * CFrame.new(-8.1, 1.1, 0), Vector3.new(0.8, 2.2, 12), Enum.Material.Wood, Color3.fromRGB(94, 70, 51), 0, nil)
	PrefabUtils.addPart(model, "FenceEast", pivot * CFrame.new(8.1, 1.1, 0), Vector3.new(0.8, 2.2, 12), Enum.Material.Wood, Color3.fromRGB(94, 70, 51), 0, nil)
	PrefabUtils.addPart(model, "FenceNorth", pivot * CFrame.new(0, 1.1, -6.1), Vector3.new(16, 2.2, 0.8), Enum.Material.Wood, Color3.fromRGB(94, 70, 51), 0, nil)
	PrefabUtils.addPart(model, "FenceSouth", pivot * CFrame.new(0, 1.1, 6.1), Vector3.new(16, 2.2, 0.8), Enum.Material.Wood, Color3.fromRGB(94, 70, 51), 0, nil)

	PrefabUtils.addPart(model, "WaterTrough", pivot * CFrame.new(6.0, 1.2, -4.5), Vector3.new(2.2, 1.2, 3.2), Enum.Material.WoodPlanks, Color3.fromRGB(102, 76, 54), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
