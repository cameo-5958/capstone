--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::NodeTentOutpost",
	Name = "NodeTentOutpost",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(20, 18),
	HeightStuds = 11,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Pad", pivot * CFrame.new(0, 1, 0), Vector3.new(16, 2, 14), Enum.Material.Ground, Color3.fromRGB(110, 94, 74), 0, nil)
	PrefabUtils.addPart(model, "TentFloor", pivot * CFrame.new(0, 2, 0), Vector3.new(10, 1, 8), Enum.Material.Fabric, Color3.fromRGB(134, 113, 92), 0, nil)

	PrefabUtils.addPart(model, "TentPoleLeft", pivot * CFrame.new(-3.5, 4.5, 0), Vector3.new(1, 5, 1), Enum.Material.Wood, Color3.fromRGB(89, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "TentPoleRight", pivot * CFrame.new(3.5, 4.5, 0), Vector3.new(1, 5, 1), Enum.Material.Wood, Color3.fromRGB(89, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "TentRidge", pivot * CFrame.new(0, 7, 0), Vector3.new(8, 1, 1), Enum.Material.Wood, Color3.fromRGB(86, 62, 44), 0, nil)

	PrefabUtils.addPart(model, "TentRoofA", pivot * CFrame.new(0, 6, -1.8), Vector3.new(9, 1, 4), Enum.Material.Fabric, Color3.fromRGB(162, 132, 98), 0, nil)
	PrefabUtils.addPart(model, "TentRoofB", pivot * CFrame.new(0, 6, 1.8), Vector3.new(9, 1, 4), Enum.Material.Fabric, Color3.fromRGB(162, 132, 98), 0, nil)

	PrefabUtils.addPart(model, "CrateA", pivot * CFrame.new(-5, 2.5, 4), Vector3.new(2, 2, 2), Enum.Material.WoodPlanks, Color3.fromRGB(108, 80, 58), 0, nil)
	PrefabUtils.addPart(model, "CrateB", pivot * CFrame.new(-2.5, 2.5, 4), Vector3.new(2, 2, 2), Enum.Material.WoodPlanks, Color3.fromRGB(103, 76, 55), 0, nil)
	PrefabUtils.addPart(model, "SupplyBarrel", pivot * CFrame.new(5, 2.8, 4), Vector3.new(2, 3, 2), Enum.Material.Wood, Color3.fromRGB(96, 70, 51), 0, "Cylinder")

	PrefabUtils.addPart(model, "ScoutLamp", pivot * CFrame.new(0, 3, -4), Vector3.new(2, 2, 2), Enum.Material.Neon, Color3.fromRGB(255, 208, 124), 0.22, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
