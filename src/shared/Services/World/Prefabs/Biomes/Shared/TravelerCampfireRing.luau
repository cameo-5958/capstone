--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::TravelerCampfireRing",
	Name = "TravelerCampfireRing",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(18, 18),
	HeightStuds = 9,
	SpawnMarkers = {
		{
			Id = "CampGuardWest",
			Type = "Enemy",
			Offset = Vector3.new(-7, 0, 0),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 10,
				LevelMax = 34,
				LevelStep = 2,
			},
		},
		{
			Id = "CampGuardEast",
			Type = "Enemy",
			Offset = Vector3.new(7, 0, 0),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 10,
				LevelMax = 34,
				LevelStep = 2,
			},
		},
		{
			Id = "CampSupplies",
			Type = "Treasure",
			Offset = Vector3.new(4.2, 0, -3.8),
			Treasure = {
				LootTableId = "CampStock",
				PromptActionText = "Loot Supplies",
				PromptObjectText = "Camp Stash",
			},
		},
	},
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "CampPad", pivot * CFrame.new(0, 0.5, 0), Vector3.new(14, 1, 14), Enum.Material.Ground, Color3.fromRGB(107, 91, 72), 0, nil)
	PrefabUtils.addPart(model, "FireRingNorth", pivot * CFrame.new(0, 1.5, -1.9), Vector3.new(4.8, 1, 1), Enum.Material.Rock, Color3.fromRGB(109, 108, 102), 0, nil)
	PrefabUtils.addPart(model, "FireRingSouth", pivot * CFrame.new(0, 1.5, 1.9), Vector3.new(4.8, 1, 1), Enum.Material.Rock, Color3.fromRGB(109, 108, 102), 0, nil)
	PrefabUtils.addPart(model, "FireRingWest", pivot * CFrame.new(-1.9, 1.5, 0), Vector3.new(1, 1, 2.8), Enum.Material.Rock, Color3.fromRGB(109, 108, 102), 0, nil)
	PrefabUtils.addPart(model, "FireRingEast", pivot * CFrame.new(1.9, 1.5, 0), Vector3.new(1, 1, 2.8), Enum.Material.Rock, Color3.fromRGB(109, 108, 102), 0, nil)
	PrefabUtils.addPart(model, "EmberCore", pivot * CFrame.new(0, 1.45, 0), Vector3.new(2.2, 0.8, 2.2), Enum.Material.Neon, Color3.fromRGB(255, 161, 74), 0.2, nil)

	PrefabUtils.addPart(model, "BenchNorth", pivot * CFrame.new(0, 1.6, -5.1), Vector3.new(6, 1.2, 1.4), Enum.Material.Wood, Color3.fromRGB(101, 73, 52), 0, nil)
	PrefabUtils.addPart(model, "BenchSouth", pivot * CFrame.new(0, 1.6, 5.1), Vector3.new(6, 1.2, 1.4), Enum.Material.Wood, Color3.fromRGB(101, 73, 52), 0, nil)
	PrefabUtils.addPart(model, "BenchWest", pivot * CFrame.new(-5.1, 1.6, 0), Vector3.new(1.4, 1.2, 6), Enum.Material.Wood, Color3.fromRGB(101, 73, 52), 0, nil)
	PrefabUtils.addPart(model, "BenchEast", pivot * CFrame.new(5.1, 1.6, 0), Vector3.new(1.4, 1.2, 6), Enum.Material.Wood, Color3.fromRGB(101, 73, 52), 0, nil)

	PrefabUtils.addPart(model, "Bedroll", pivot * CFrame.new(-4.2, 1.15, 3.8), Vector3.new(3.4, 0.8, 1.8), Enum.Material.Fabric, Color3.fromRGB(142, 123, 97), 0, nil)
	PrefabUtils.addPart(model, "SupplyCrate", pivot * CFrame.new(4.2, 1.4, -3.8), Vector3.new(2.1, 1.8, 2.1), Enum.Material.WoodPlanks, Color3.fromRGB(108, 79, 57), 0, nil)
	PrefabUtils.addPart(model, "LanternGlow", pivot * CFrame.new(4.1, 2.5, -3.8), Vector3.new(1.2, 1.2, 1.2), Enum.Material.Neon, Color3.fromRGB(255, 213, 134), 0.2, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
