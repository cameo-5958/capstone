--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "HighlandDesert::OasisFireCamp",
	Name = "OasisFireCamp",
	Biome = "HighlandDesert",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(18, 14),
	HeightStuds = 9,
	SpawnMarkers = {
		{
			Id = "OasisGuardNorth",
			Type = "Enemy",
			Offset = Vector3.new(0, 0, -6),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 14,
				LevelMax = 36,
				LevelStep = 2,
			},
		},
		{
			Id = "OasisGuardSouth",
			Type = "Enemy",
			Offset = Vector3.new(0, 0, 6),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 14,
				LevelMax = 36,
				LevelStep = 2,
			},
		},
		{
			Id = "OasisCache",
			Type = "Treasure",
			Offset = Vector3.new(-5.8, 0, 1.6),
			Treasure = {
				LootTableId = "CampStock",
				PromptActionText = "Search Supplies",
				PromptObjectText = "Oasis Supplies",
			},
		},
	},
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "SandPad", pivot * CFrame.new(0, 0.5, 0), Vector3.new(14, 1, 10), Enum.Material.Sand, Color3.fromRGB(186, 152, 106), 0, nil)
	PrefabUtils.addPart(model, "RugBase", pivot * CFrame.new(0, 1.1, 0), Vector3.new(10, 0.3, 6), Enum.Material.Fabric, Color3.fromRGB(164, 118, 82), 0, nil)

	PrefabUtils.addPart(model, "FireRingNorth", pivot * CFrame.new(0, 1.55, -1.6), Vector3.new(4.0, 0.9, 0.9), Enum.Material.Sandstone, Color3.fromRGB(152, 128, 94), 0, nil)
	PrefabUtils.addPart(model, "FireRingSouth", pivot * CFrame.new(0, 1.55, 1.6), Vector3.new(4.0, 0.9, 0.9), Enum.Material.Sandstone, Color3.fromRGB(152, 128, 94), 0, nil)
	PrefabUtils.addPart(model, "FireRingWest", pivot * CFrame.new(-1.6, 1.55, 0), Vector3.new(0.9, 0.9, 2.2), Enum.Material.Sandstone, Color3.fromRGB(152, 128, 94), 0, nil)
	PrefabUtils.addPart(model, "FireRingEast", pivot * CFrame.new(1.6, 1.55, 0), Vector3.new(0.9, 0.9, 2.2), Enum.Material.Sandstone, Color3.fromRGB(152, 128, 94), 0, nil)
	PrefabUtils.addPart(model, "FireCore", pivot * CFrame.new(0, 1.5, 0), Vector3.new(1.9, 0.7, 1.9), Enum.Material.Neon, Color3.fromRGB(255, 170, 78), 0.22, nil)

	PrefabUtils.addPart(model, "CanopyPostA", pivot * CFrame.new(4.8, 3.7, -2.3), Vector3.new(0.8, 4.4, 0.8), Enum.Material.Wood, Color3.fromRGB(98, 72, 52), 0, nil)
	PrefabUtils.addPart(model, "CanopyPostB", pivot * CFrame.new(7.6, 3.7, -2.3), Vector3.new(0.8, 4.4, 0.8), Enum.Material.Wood, Color3.fromRGB(98, 72, 52), 0, nil)
	PrefabUtils.addPart(model, "CanopyPostC", pivot * CFrame.new(4.8, 3.7, 2.3), Vector3.new(0.8, 4.4, 0.8), Enum.Material.Wood, Color3.fromRGB(98, 72, 52), 0, nil)
	PrefabUtils.addPart(model, "CanopyPostD", pivot * CFrame.new(7.6, 3.7, 2.3), Vector3.new(0.8, 4.4, 0.8), Enum.Material.Wood, Color3.fromRGB(98, 72, 52), 0, nil)
	PrefabUtils.addPart(model, "CanopyCloth", pivot * CFrame.new(6.2, 6.1, 0), Vector3.new(3.8, 0.8, 4.8), Enum.Material.Fabric, Color3.fromRGB(193, 155, 102), 0, nil)

	PrefabUtils.addPart(model, "WaterJarA", pivot * CFrame.new(-4.5, 1.8, -1.9), Vector3.new(1.2, 1.8, 1.2), Enum.Material.Sandstone, Color3.fromRGB(172, 136, 96), 0, nil)
	PrefabUtils.addPart(model, "WaterJarB", pivot * CFrame.new(-5.8, 1.8, 1.6), Vector3.new(1.2, 1.8, 1.2), Enum.Material.Sandstone, Color3.fromRGB(172, 136, 96), 0, nil)
	PrefabUtils.addPart(model, "SupplyCrate", pivot * CFrame.new(2.4, 1.8, 3.3), Vector3.new(2.1, 1.4, 1.8), Enum.Material.WoodPlanks, Color3.fromRGB(108, 81, 56), 0, nil)
	PrefabUtils.addPart(model, "ShadeLamp", pivot * CFrame.new(6.2, 4.6, 0), Vector3.new(1.0, 1.0, 1.0), Enum.Material.Neon, Color3.fromRGB(255, 212, 136), 0.2, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
