--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::TreasureChestCampStock",
	Name = "TreasureChestCampStock",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(12, 12),
	HeightStuds = 8,
	SpawnMarkers = {
		{
			Id = "CampTreasure",
			Type = "Treasure",
			Offset = Vector3.new(0, 0, 0),
			Treasure = {
				LootTableId = "CampStock",
				PromptActionText = "Open Cache",
				PromptObjectText = "Supply Chest",
			},
		},
		{
			Id = "CampGuardian",
			Type = "Enemy",
			Offset = Vector3.new(6, 0, -3),
			Enemy = {
				PoolId = "Camp.Elite",
				LevelMin = 20,
				LevelMax = 48,
				LevelStep = 2,
			},
		},
	},
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "CampPad", pivot * CFrame.new(0, 0.5, 0), Vector3.new(10, 1, 10), Enum.Material.Ground, Color3.fromRGB(108, 92, 74), 0, nil)
	PrefabUtils.addPart(model, "CrateA", pivot * CFrame.new(-2.8, 1.5, -1.8), Vector3.new(2, 2, 2), Enum.Material.WoodPlanks, Color3.fromRGB(111, 82, 57), 0, nil)
	PrefabUtils.addPart(model, "CrateB", pivot * CFrame.new(2.9, 1.5, 2.0), Vector3.new(2, 2, 2), Enum.Material.WoodPlanks, Color3.fromRGB(104, 76, 54), 0, nil)
	PrefabUtils.addPart(model, "Supplies", pivot * CFrame.new(0.2, 1.25, 3.2), Vector3.new(4, 1.5, 2), Enum.Material.Wood, Color3.fromRGB(96, 72, 49), 0, nil)

	PrefabUtils.addPart(model, "ChestBase", pivot * CFrame.new(0, 1.75, 0), Vector3.new(3.8, 2.5, 2.4), Enum.Material.WoodPlanks, Color3.fromRGB(93, 64, 40), 0, nil)
	PrefabUtils.addPart(model, "ChestLid", pivot * CFrame.new(0, 3.25, 0), Vector3.new(3.8, 1.0, 2.5), Enum.Material.WoodPlanks, Color3.fromRGB(110, 76, 47), 0, nil)
	PrefabUtils.addPart(model, "ChestStripe", pivot * CFrame.new(0, 3.78, 0), Vector3.new(3.4, 0.28, 2.54), Enum.Material.SmoothPlastic, Color3.fromRGB(192, 116, 66), 0, nil)
	PrefabUtils.addPart(model, "ChestBand", pivot * CFrame.new(0, 2.35, -1.26), Vector3.new(3.8, 0.7, 0.25), Enum.Material.Metal, Color3.fromRGB(156, 136, 84), 0, nil)
	PrefabUtils.addPart(model, "ChestLock", pivot * CFrame.new(0, 2.2, -1.43), Vector3.new(0.7, 0.6, 0.2), Enum.Material.Metal, Color3.fromRGB(208, 172, 88), 0, nil)

	PrefabUtils.addPart(model, "LanternGlow", pivot * CFrame.new(-3.1, 2.2, 2.9), Vector3.new(1, 1, 1), Enum.Material.Neon, Color3.fromRGB(255, 214, 136), 0.22, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
