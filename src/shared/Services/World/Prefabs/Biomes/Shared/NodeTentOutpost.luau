--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::NodeTentOutpost",
	Name = "NodeTentOutpost",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(16, 14),
	HeightStuds = 11,
	SpawnMarkers = {
		{
			Id = "OutpostGuardFront",
			Type = "Enemy",
			Offset = Vector3.new(0, 0, -5.5),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 12,
				LevelMax = 34,
				LevelStep = 2,
			},
		},
		{
			Id = "OutpostGuardRear",
			Type = "Enemy",
			Offset = Vector3.new(0, 0, 5.5),
			Enemy = {
				PoolId = "Camp.Guards",
				LevelMin = 12,
				LevelMax = 34,
				LevelStep = 2,
			},
		},
		{
			Id = "OutpostChest",
			Type = "Treasure",
			Offset = Vector3.new(-3.5, 0, 3),
			Treasure = {
				LootTableId = "FieldCache",
				PromptActionText = "Open Crate",
				PromptObjectText = "Outpost Crate",
			},
		},
	},
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Pad", pivot * CFrame.new(0, 1, 0), Vector3.new(13, 2, 11), Enum.Material.Ground, Color3.fromRGB(110, 94, 74), 0, nil)
	PrefabUtils.addPart(model, "TentFloor", pivot * CFrame.new(0, 2, 0), Vector3.new(8, 1, 6), Enum.Material.Fabric, Color3.fromRGB(134, 113, 92), 0, nil)

	PrefabUtils.addPart(model, "TentPoleLeft", pivot * CFrame.new(-2.8, 4.5, 0), Vector3.new(1, 5, 1), Enum.Material.Wood, Color3.fromRGB(89, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "TentPoleRight", pivot * CFrame.new(2.8, 4.5, 0), Vector3.new(1, 5, 1), Enum.Material.Wood, Color3.fromRGB(89, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "TentRidge", pivot * CFrame.new(0, 7, 0), Vector3.new(6.5, 1, 1), Enum.Material.Wood, Color3.fromRGB(86, 62, 44), 0, nil)

	PrefabUtils.addPart(model, "TentRoofA", pivot * CFrame.new(0, 6, -1.3), Vector3.new(7.5, 1, 3.2), Enum.Material.Fabric, Color3.fromRGB(162, 132, 98), 0, nil)
	PrefabUtils.addPart(model, "TentRoofB", pivot * CFrame.new(0, 6, 1.3), Vector3.new(7.5, 1, 3.2), Enum.Material.Fabric, Color3.fromRGB(162, 132, 98), 0, nil)

	PrefabUtils.addPart(model, "CrateA", pivot * CFrame.new(-3.5, 2.5, 3), Vector3.new(2, 2, 2), Enum.Material.WoodPlanks, Color3.fromRGB(108, 80, 58), 0, nil)
	PrefabUtils.addPart(model, "CrateB", pivot * CFrame.new(-1.2, 2.5, 3), Vector3.new(2, 2, 2), Enum.Material.WoodPlanks, Color3.fromRGB(103, 76, 55), 0, nil)

	PrefabUtils.addPart(model, "ScoutLamp", pivot * CFrame.new(0, 3, -3.1), Vector3.new(2, 2, 2), Enum.Material.Neon, Color3.fromRGB(255, 208, 124), 0.22, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
