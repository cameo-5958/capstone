--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::TownhouseNarrow",
	Name = "TownhouseNarrow",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(24, 34),
	HeightStuds = 40,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Foundation", pivot * CFrame.new(0, 1, 0), Vector3.new(18, 2, 28), Enum.Material.Slate, Color3.fromRGB(111, 113, 121), 0, nil)
	PrefabUtils.addPart(model, "FloorA", pivot * CFrame.new(0, 2.7, 0), Vector3.new(16, 0.9, 26), Enum.Material.WoodPlanks, Color3.fromRGB(118, 87, 63), 0, nil)
	PrefabUtils.addPart(model, "FloorB", pivot * CFrame.new(0, 13.4, 0), Vector3.new(14, 0.9, 24), Enum.Material.WoodPlanks, Color3.fromRGB(114, 82, 60), 0, nil)
	PrefabUtils.addPart(model, "FloorC", pivot * CFrame.new(0, 22.8, 0), Vector3.new(12, 0.9, 20), Enum.Material.WoodPlanks, Color3.fromRGB(110, 79, 58), 0, nil)

	PrefabUtils.addPart(model, "WallNorthLower", pivot * CFrame.new(0, 7.9, -12.8), Vector3.new(16, 9, 1), Enum.Material.Brick, Color3.fromRGB(168, 154, 140), 0, nil)
	PrefabUtils.addPart(model, "WallSouthLower", pivot * CFrame.new(0, 7.9, 12.8), Vector3.new(16, 9, 1), Enum.Material.Brick, Color3.fromRGB(168, 154, 140), 0, nil)
	PrefabUtils.addPart(model, "WallWestLower", pivot * CFrame.new(-7.8, 7.9, 0), Vector3.new(1, 9, 24), Enum.Material.Brick, Color3.fromRGB(168, 154, 140), 0, nil)
	PrefabUtils.addPart(model, "WallEastLower", pivot * CFrame.new(7.8, 7.9, 0), Vector3.new(1, 9, 24), Enum.Material.Brick, Color3.fromRGB(168, 154, 140), 0, nil)

	PrefabUtils.addPart(model, "BeltA", pivot * CFrame.new(0, 11.9, 0), Vector3.new(16, 0.8, 26), Enum.Material.Wood, Color3.fromRGB(96, 68, 48), 0, nil)

	PrefabUtils.addPart(model, "WallNorthMid", pivot * CFrame.new(0, 17.4, -11.8), Vector3.new(14, 7, 1), Enum.Material.WoodPlanks, Color3.fromRGB(147, 111, 81), 0, nil)
	PrefabUtils.addPart(model, "WallSouthMid", pivot * CFrame.new(0, 17.4, 11.8), Vector3.new(14, 7, 1), Enum.Material.WoodPlanks, Color3.fromRGB(147, 111, 81), 0, nil)
	PrefabUtils.addPart(model, "WallWestMid", pivot * CFrame.new(-6.8, 17.4, 0), Vector3.new(1, 7, 22), Enum.Material.WoodPlanks, Color3.fromRGB(147, 111, 81), 0, nil)
	PrefabUtils.addPart(model, "WallEastMid", pivot * CFrame.new(6.8, 17.4, 0), Vector3.new(1, 7, 22), Enum.Material.WoodPlanks, Color3.fromRGB(147, 111, 81), 0, nil)

	PrefabUtils.addPart(model, "BeltB", pivot * CFrame.new(0, 20.8, 0), Vector3.new(14, 0.8, 24), Enum.Material.Wood, Color3.fromRGB(92, 66, 47), 0, nil)

	PrefabUtils.addPart(model, "WallNorthTop", pivot * CFrame.new(0, 26.2, -10.1), Vector3.new(12, 6, 1), Enum.Material.WoodPlanks, Color3.fromRGB(154, 118, 88), 0, nil)
	PrefabUtils.addPart(model, "WallSouthTop", pivot * CFrame.new(0, 26.2, 10.1), Vector3.new(12, 6, 1), Enum.Material.WoodPlanks, Color3.fromRGB(154, 118, 88), 0, nil)
	PrefabUtils.addPart(model, "WallWestTop", pivot * CFrame.new(-5.8, 26.2, 0), Vector3.new(1, 6, 18), Enum.Material.WoodPlanks, Color3.fromRGB(154, 118, 88), 0, nil)
	PrefabUtils.addPart(model, "WallEastTop", pivot * CFrame.new(5.8, 26.2, 0), Vector3.new(1, 6, 18), Enum.Material.WoodPlanks, Color3.fromRGB(154, 118, 88), 0, nil)

	PrefabUtils.addPart(model, "DoorFrame", pivot * CFrame.new(0, 4.8, 12.9), Vector3.new(4.6, 5.8, 1), Enum.Material.Wood, Color3.fromRGB(96, 68, 48), 0, nil)
	PrefabUtils.addPart(model, "DoorInset", pivot * CFrame.new(0, 4.8, 13.0), Vector3.new(3.0, 4.4, 1), Enum.Material.WoodPlanks, Color3.fromRGB(104, 74, 53), 0, nil)
	PrefabUtils.addPart(model, "EntryStoop", pivot * CFrame.new(0, 2.2, 15.2), Vector3.new(6.0, 0.8, 3.0), Enum.Material.WoodPlanks, Color3.fromRGB(102, 75, 55), 0, nil)

	PrefabUtils.addPart(model, "WindowLowerNorth", pivot * CFrame.new(0, 8.2, -12.9), Vector3.new(4.0, 3.2, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowMidNorth", pivot * CFrame.new(0, 17.2, -11.9), Vector3.new(3.6, 3.0, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowTopNorth", pivot * CFrame.new(0, 26.0, -10.2), Vector3.new(3.0, 2.8, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowWestMid", pivot * CFrame.new(-6.9, 17.2, 2.4), Vector3.new(1, 3.0, 3.0), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowEastMid", pivot * CFrame.new(6.9, 17.2, -2.4), Vector3.new(1, 3.0, 3.0), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)

	PrefabUtils.addPart(model, "RoofMain", pivot * CFrame.new(0, 30.6, 0), Vector3.new(16, 1.9, 26), Enum.Material.WoodPlanks, Color3.fromRGB(111, 79, 56), 0, nil)
	PrefabUtils.addPart(model, "RoofCap", pivot * CFrame.new(0, 32.8, 0), Vector3.new(11, 1.8, 20), Enum.Material.WoodPlanks, Color3.fromRGB(100, 72, 50), 0, nil)
	PrefabUtils.addPart(model, "RoofTrimFront", pivot * CFrame.new(0, 30.0, 13.2), Vector3.new(16, 0.8, 1), Enum.Material.Wood, Color3.fromRGB(86, 63, 47), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
