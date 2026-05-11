--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Forest::ForagerSupplyCamp",
	Name = "ForagerSupplyCamp",
	Biome = "Forest",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(18, 16),
	HeightStuds = 10,
	SpawnMarkers = {
		{
			Id = "ForagerGuard",
			Type = "Enemy",
			Offset = Vector3.new(-6.0, 0, 0),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 16,
				LevelMax = 40,
				LevelStep = 2,
			},
		},
		{
			Id = "ForagerCache",
			Type = "Treasure",
			Offset = Vector3.new(5.7, 0, 1.1),
			Treasure = {
				LootTableId = "CampStock",
				PromptActionText = "Check Crate",
				PromptObjectText = "Forager Crate",
			},
		},
	},
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "ClearingPad", pivot * CFrame.new(0, 0.5, 0), Vector3.new(14, 1, 12), Enum.Material.Ground, Color3.fromRGB(100, 84, 66), 0, nil)
	PrefabUtils.addPart(model, "RaisedDeck", pivot * CFrame.new(-2.8, 1.7, 0), Vector3.new(7.2, 1.2, 5.4), Enum.Material.WoodPlanks, Color3.fromRGB(95, 70, 50), 0, nil)
	PrefabUtils.addPart(model, "DeckRailNorth", pivot * CFrame.new(-2.8, 2.4, -2.3), Vector3.new(7.2, 0.8, 0.6), Enum.Material.Wood, Color3.fromRGB(86, 63, 46), 0, nil)
	PrefabUtils.addPart(model, "DeckRailSouth", pivot * CFrame.new(-2.8, 2.4, 2.3), Vector3.new(7.2, 0.8, 0.6), Enum.Material.Wood, Color3.fromRGB(86, 63, 46), 0, nil)

	PrefabUtils.addPart(model, "CanopyPostA", pivot * CFrame.new(2.0, 4.3, -2.0), Vector3.new(0.8, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(82, 60, 43), 0, nil)
	PrefabUtils.addPart(model, "CanopyPostB", pivot * CFrame.new(6.8, 4.3, -2.0), Vector3.new(0.8, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(82, 60, 43), 0, nil)
	PrefabUtils.addPart(model, "CanopyPostC", pivot * CFrame.new(2.0, 4.3, 2.0), Vector3.new(0.8, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(82, 60, 43), 0, nil)
	PrefabUtils.addPart(model, "CanopyPostD", pivot * CFrame.new(6.8, 4.3, 2.0), Vector3.new(0.8, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(82, 60, 43), 0, nil)
	PrefabUtils.addPart(model, "CanopyRoof", pivot * CFrame.new(4.4, 7.1, 0), Vector3.new(5.8, 0.9, 5.0), Enum.Material.Fabric, Color3.fromRGB(124, 132, 98), 0, nil)

	PrefabUtils.addPart(model, "CrateMushroom", pivot * CFrame.new(3.2, 2.5, -1.1), Vector3.new(1.8, 1.5, 1.8), Enum.Material.WoodPlanks, Color3.fromRGB(102, 76, 56), 0, nil)
	PrefabUtils.addPart(model, "CrateHerbs", pivot * CFrame.new(5.7, 2.5, 1.1), Vector3.new(1.8, 1.5, 1.8), Enum.Material.WoodPlanks, Color3.fromRGB(102, 76, 56), 0, nil)
	PrefabUtils.addPart(model, "GatherPileA", pivot * CFrame.new(3.2, 3.2, -1.1), Vector3.new(1.3, 0.7, 1.3), Enum.Material.Grass, Color3.fromRGB(96, 138, 78), 0, nil)
	PrefabUtils.addPart(model, "GatherPileB", pivot * CFrame.new(5.7, 3.2, 1.1), Vector3.new(1.3, 0.7, 1.3), Enum.Material.Grass, Color3.fromRGB(146, 122, 82), 0, nil)

	PrefabUtils.addPart(model, "PackingTable", pivot * CFrame.new(-6.0, 2.2, 0), Vector3.new(3.0, 1.0, 4.4), Enum.Material.Wood, Color3.fromRGB(92, 67, 49), 0, nil)
	PrefabUtils.addPart(model, "LanternGlow", pivot * CFrame.new(-6.0, 3.3, -1.8), Vector3.new(1.0, 1.0, 1.0), Enum.Material.Neon, Color3.fromRGB(255, 205, 124), 0.2, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
