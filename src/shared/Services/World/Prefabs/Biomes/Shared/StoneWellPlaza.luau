--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::StoneWellPlaza",
	Name = "StoneWellPlaza",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(16, 16),
	HeightStuds = 12,
	SpawnMarkers = {
		{
			Id = "WellSentinel",
			Type = "Enemy",
			Offset = Vector3.new(-6, 0, 0),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 10,
				LevelMax = 30,
				LevelStep = 2,
			},
		},
		{
			Id = "WellRelic",
			Type = "Treasure",
			Offset = Vector3.new(0, 0, 3),
			Treasure = {
				LootTableId = "FieldCache",
				PromptActionText = "Inspect Well",
				PromptObjectText = "Well Stash",
			},
		},
	},
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "PlazaPad", pivot * CFrame.new(0, 0.5, 0), Vector3.new(12, 1, 12), Enum.Material.Cobblestone, Color3.fromRGB(123, 120, 113), 0, nil)
	PrefabUtils.addPart(model, "WellNorth", pivot * CFrame.new(0, 1.9, -1.8), Vector3.new(5, 1.8, 1), Enum.Material.Rock, Color3.fromRGB(106, 104, 98), 0, nil)
	PrefabUtils.addPart(model, "WellSouth", pivot * CFrame.new(0, 1.9, 1.8), Vector3.new(5, 1.8, 1), Enum.Material.Rock, Color3.fromRGB(106, 104, 98), 0, nil)
	PrefabUtils.addPart(model, "WellWest", pivot * CFrame.new(-1.8, 1.9, 0), Vector3.new(1, 1.8, 3), Enum.Material.Rock, Color3.fromRGB(106, 104, 98), 0, nil)
	PrefabUtils.addPart(model, "WellEast", pivot * CFrame.new(1.8, 1.9, 0), Vector3.new(1, 1.8, 3), Enum.Material.Rock, Color3.fromRGB(106, 104, 98), 0, nil)
	PrefabUtils.addPart(model, "WellWater", pivot * CFrame.new(0, 1.4, 0), Vector3.new(2.8, 0.8, 2.8), Enum.Material.Water, Color3.fromRGB(82, 140, 188), 0.1, nil)

	PrefabUtils.addPart(model, "PostNorthWest", pivot * CFrame.new(-2.2, 5.1, -2.2), Vector3.new(0.9, 6.2, 0.9), Enum.Material.Wood, Color3.fromRGB(89, 64, 44), 0, nil)
	PrefabUtils.addPart(model, "PostNorthEast", pivot * CFrame.new(2.2, 5.1, -2.2), Vector3.new(0.9, 6.2, 0.9), Enum.Material.Wood, Color3.fromRGB(89, 64, 44), 0, nil)
	PrefabUtils.addPart(model, "PostSouthWest", pivot * CFrame.new(-2.2, 5.1, 2.2), Vector3.new(0.9, 6.2, 0.9), Enum.Material.Wood, Color3.fromRGB(89, 64, 44), 0, nil)
	PrefabUtils.addPart(model, "PostSouthEast", pivot * CFrame.new(2.2, 5.1, 2.2), Vector3.new(0.9, 6.2, 0.9), Enum.Material.Wood, Color3.fromRGB(89, 64, 44), 0, nil)
	PrefabUtils.addPart(model, "RoofBeamNorth", pivot * CFrame.new(0, 8.2, -2.2), Vector3.new(5.4, 0.8, 0.8), Enum.Material.Wood, Color3.fromRGB(92, 67, 47), 0, nil)
	PrefabUtils.addPart(model, "RoofBeamSouth", pivot * CFrame.new(0, 8.2, 2.2), Vector3.new(5.4, 0.8, 0.8), Enum.Material.Wood, Color3.fromRGB(92, 67, 47), 0, nil)
	PrefabUtils.addPart(model, "RoofPanel", pivot * CFrame.new(0, 9.1, 0), Vector3.new(6.2, 1.2, 5.2), Enum.Material.WoodPlanks, Color3.fromRGB(113, 84, 60), 0, nil)

	PrefabUtils.addPart(model, "BucketBody", pivot * CFrame.new(0, 3.2, 0.9), Vector3.new(1.4, 1.6, 1.4), Enum.Material.WoodPlanks, Color3.fromRGB(110, 80, 56), 0, nil)
	PrefabUtils.addPart(model, "BucketHandle", pivot * CFrame.new(0, 4.4, 0.9), Vector3.new(1.6, 0.4, 0.4), Enum.Material.Metal, Color3.fromRGB(118, 118, 123), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
