--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::TimberHouseTall",
	Name = "TimberHouseTall",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(22, 18),
	HeightStuds = 30,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "StoneBase", pivot * CFrame.new(0, 1, 0), Vector3.new(18, 2, 14), Enum.Material.Slate, Color3.fromRGB(109, 109, 118), 0, nil)
	PrefabUtils.addPart(model, "FloorA", pivot * CFrame.new(0, 2.5, 0), Vector3.new(16, 1, 12), Enum.Material.WoodPlanks, Color3.fromRGB(119, 87, 60), 0, nil)
	PrefabUtils.addPart(model, "FloorB", pivot * CFrame.new(0, 11.5, 0), Vector3.new(14, 1, 10), Enum.Material.WoodPlanks, Color3.fromRGB(115, 83, 58), 0, nil)

	PrefabUtils.addPart(model, "FrameCornerNW", pivot * CFrame.new(-7.5, 7, -5.5), Vector3.new(1, 10, 1), Enum.Material.Wood, Color3.fromRGB(86, 59, 41), 0, nil)
	PrefabUtils.addPart(model, "FrameCornerNE", pivot * CFrame.new(7.5, 7, -5.5), Vector3.new(1, 10, 1), Enum.Material.Wood, Color3.fromRGB(86, 59, 41), 0, nil)
	PrefabUtils.addPart(model, "FrameCornerSW", pivot * CFrame.new(-7.5, 7, 5.5), Vector3.new(1, 10, 1), Enum.Material.Wood, Color3.fromRGB(86, 59, 41), 0, nil)
	PrefabUtils.addPart(model, "FrameCornerSE", pivot * CFrame.new(7.5, 7, 5.5), Vector3.new(1, 10, 1), Enum.Material.Wood, Color3.fromRGB(86, 59, 41), 0, nil)

	PrefabUtils.addPart(model, "WallNorthLower", pivot * CFrame.new(0, 7, -5.6), Vector3.new(14, 8, 1), Enum.Material.WoodPlanks, Color3.fromRGB(148, 112, 81), 0, nil)
	PrefabUtils.addPart(model, "WallSouthLowerLeft", pivot * CFrame.new(-4.5, 7, 5.6), Vector3.new(7, 8, 1), Enum.Material.WoodPlanks, Color3.fromRGB(148, 112, 81), 0, nil)
	PrefabUtils.addPart(model, "WallSouthLowerRight", pivot * CFrame.new(4.5, 7, 5.6), Vector3.new(7, 8, 1), Enum.Material.WoodPlanks, Color3.fromRGB(148, 112, 81), 0, nil)
	PrefabUtils.addPart(model, "WallWestLower", pivot * CFrame.new(-7.6, 7, 0), Vector3.new(1, 8, 10), Enum.Material.WoodPlanks, Color3.fromRGB(148, 112, 81), 0, nil)
	PrefabUtils.addPart(model, "WallEastLower", pivot * CFrame.new(7.6, 7, 0), Vector3.new(1, 8, 10), Enum.Material.WoodPlanks, Color3.fromRGB(148, 112, 81), 0, nil)

	PrefabUtils.addPart(model, "WallNorthUpper", pivot * CFrame.new(0, 16, -4.6), Vector3.new(12, 6, 1), Enum.Material.WoodPlanks, Color3.fromRGB(156, 120, 90), 0, nil)
	PrefabUtils.addPart(model, "WallSouthUpper", pivot * CFrame.new(0, 16, 4.6), Vector3.new(12, 6, 1), Enum.Material.WoodPlanks, Color3.fromRGB(156, 120, 90), 0, nil)
	PrefabUtils.addPart(model, "WallWestUpper", pivot * CFrame.new(-6.6, 16, 0), Vector3.new(1, 6, 8), Enum.Material.WoodPlanks, Color3.fromRGB(156, 120, 90), 0, nil)
	PrefabUtils.addPart(model, "WallEastUpper", pivot * CFrame.new(6.6, 16, 0), Vector3.new(1, 6, 8), Enum.Material.WoodPlanks, Color3.fromRGB(156, 120, 90), 0, nil)

	PrefabUtils.addPart(model, "Door", pivot * CFrame.new(0, 4.5, 5.7), Vector3.new(3, 5, 1), Enum.Material.Wood, Color3.fromRGB(99, 70, 49), 0, nil)
	PrefabUtils.addPart(model, "WindowLowerNorth", pivot * CFrame.new(0, 7.5, -5.7), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(193, 220, 238), 0.2, nil)
	PrefabUtils.addPart(model, "WindowUpperSouth", pivot * CFrame.new(0, 16.5, 4.7), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(193, 220, 238), 0.2, nil)

	PrefabUtils.addPart(model, "RoofLower", pivot * CFrame.new(0, 20, 0), Vector3.new(18, 2, 14), Enum.Material.WoodPlanks, Color3.fromRGB(115, 82, 56), 0, nil)
	PrefabUtils.addPart(model, "RoofUpper", pivot * CFrame.new(0, 23, 0), Vector3.new(12, 2, 10), Enum.Material.WoodPlanks, Color3.fromRGB(106, 76, 52), 0, nil)

	PrefabUtils.addPart(model, "Chimney", pivot * CFrame.new(4, 23.5, -3), Vector3.new(2, 7, 2), Enum.Material.Rock, Color3.fromRGB(113, 114, 124), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
