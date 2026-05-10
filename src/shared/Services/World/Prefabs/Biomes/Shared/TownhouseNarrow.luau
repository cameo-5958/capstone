--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::TownhouseNarrow",
	Name = "TownhouseNarrow",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(16, 22),
	HeightStuds = 26,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Foundation", pivot * CFrame.new(0, 1, 0), Vector3.new(12, 2, 18), Enum.Material.Slate, Color3.fromRGB(111, 113, 121), 0, nil)
	PrefabUtils.addPart(model, "FloorA", pivot * CFrame.new(0, 2.5, 0), Vector3.new(10, 1, 16), Enum.Material.WoodPlanks, Color3.fromRGB(118, 87, 63), 0, nil)
	PrefabUtils.addPart(model, "FloorB", pivot * CFrame.new(0, 11.5, 0), Vector3.new(10, 1, 16), Enum.Material.WoodPlanks, Color3.fromRGB(114, 82, 60), 0, nil)

	PrefabUtils.addPart(model, "WallNorth", pivot * CFrame.new(0, 7, -7.5), Vector3.new(10, 9, 1), Enum.Material.Brick, Color3.fromRGB(168, 154, 140), 0, nil)
	PrefabUtils.addPart(model, "WallSouth", pivot * CFrame.new(0, 7, 7.5), Vector3.new(10, 9, 1), Enum.Material.Brick, Color3.fromRGB(168, 154, 140), 0, nil)
	PrefabUtils.addPart(model, "WallWest", pivot * CFrame.new(-4.5, 7, 0), Vector3.new(1, 9, 14), Enum.Material.Brick, Color3.fromRGB(168, 154, 140), 0, nil)
	PrefabUtils.addPart(model, "WallEast", pivot * CFrame.new(4.5, 7, 0), Vector3.new(1, 9, 14), Enum.Material.Brick, Color3.fromRGB(168, 154, 140), 0, nil)

	PrefabUtils.addPart(model, "UpperNorth", pivot * CFrame.new(0, 16, -6.5), Vector3.new(10, 7, 1), Enum.Material.WoodPlanks, Color3.fromRGB(147, 111, 81), 0, nil)
	PrefabUtils.addPart(model, "UpperSouth", pivot * CFrame.new(0, 16, 6.5), Vector3.new(10, 7, 1), Enum.Material.WoodPlanks, Color3.fromRGB(147, 111, 81), 0, nil)
	PrefabUtils.addPart(model, "UpperWest", pivot * CFrame.new(-4.5, 16, 0), Vector3.new(1, 7, 12), Enum.Material.WoodPlanks, Color3.fromRGB(147, 111, 81), 0, nil)
	PrefabUtils.addPart(model, "UpperEast", pivot * CFrame.new(4.5, 16, 0), Vector3.new(1, 7, 12), Enum.Material.WoodPlanks, Color3.fromRGB(147, 111, 81), 0, nil)

	PrefabUtils.addPart(model, "DoorFrame", pivot * CFrame.new(0, 4, 7.6), Vector3.new(4, 6, 1), Enum.Material.Wood, Color3.fromRGB(96, 68, 48), 0, nil)
	PrefabUtils.addPart(model, "DoorInset", pivot * CFrame.new(0, 4, 7.7), Vector3.new(2, 4, 1), Enum.Material.WoodPlanks, Color3.fromRGB(104, 74, 53), 0, nil)

	PrefabUtils.addPart(model, "WindowA", pivot * CFrame.new(0, 7.2, -7.6), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowB", pivot * CFrame.new(0, 16.2, -6.6), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowC", pivot * CFrame.new(-4.6, 16.2, 0), Vector3.new(1, 3, 3), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)

	PrefabUtils.addPart(model, "RoofMain", pivot * CFrame.new(0, 21, 0), Vector3.new(12, 2, 18), Enum.Material.WoodPlanks, Color3.fromRGB(111, 79, 56), 0, nil)
	PrefabUtils.addPart(model, "RoofCap", pivot * CFrame.new(0, 23, 0), Vector3.new(8, 2, 12), Enum.Material.WoodPlanks, Color3.fromRGB(100, 72, 50), 0, nil)
	PrefabUtils.addPart(model, "RoofTrimFront", pivot * CFrame.new(0, 20.2, 8.8), Vector3.new(12, 1, 1), Enum.Material.Wood, Color3.fromRGB(86, 63, 47), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
