--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::CobbleHouseB",
	Name = "CobbleHouseB",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(34, 28),
	HeightStuds = 31,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Foundation", pivot * CFrame.new(0, 1, 0), Vector3.new(30, 2, 24), Enum.Material.Slate, Color3.fromRGB(104, 108, 118), 0, nil)
	PrefabUtils.addPart(model, "FloorLower", pivot * CFrame.new(0, 2.6, 0), Vector3.new(27, 0.9, 21), Enum.Material.WoodPlanks, Color3.fromRGB(121, 92, 68), 0, nil)
	PrefabUtils.addPart(model, "FloorUpper", pivot * CFrame.new(0, 12.4, 0), Vector3.new(24, 0.9, 18), Enum.Material.WoodPlanks, Color3.fromRGB(116, 86, 63), 0, nil)

	PrefabUtils.addPart(model, "WallNorthLower", pivot * CFrame.new(0, 7.3, -10.4), Vector3.new(26, 8, 1), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)
	PrefabUtils.addPart(model, "WallSouthLowerLeft", pivot * CFrame.new(-6.0, 7.3, 10.4), Vector3.new(10.8, 8, 1), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)
	PrefabUtils.addPart(model, "WallSouthLowerRight", pivot * CFrame.new(6.0, 7.3, 10.4), Vector3.new(10.8, 8, 1), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)
	PrefabUtils.addPart(model, "WallWestLower", pivot * CFrame.new(-12.8, 7.3, 0), Vector3.new(1, 8, 20), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)
	PrefabUtils.addPart(model, "WallEastLower", pivot * CFrame.new(12.8, 7.3, 0), Vector3.new(1, 8, 20), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)

	PrefabUtils.addPart(model, "WallNorthUpper", pivot * CFrame.new(0, 15.7, -9.0), Vector3.new(22, 6, 1), Enum.Material.WoodPlanks, Color3.fromRGB(152, 118, 88), 0, nil)
	PrefabUtils.addPart(model, "WallSouthUpper", pivot * CFrame.new(0, 15.7, 9.0), Vector3.new(22, 6, 1), Enum.Material.WoodPlanks, Color3.fromRGB(152, 118, 88), 0, nil)
	PrefabUtils.addPart(model, "WallWestUpper", pivot * CFrame.new(-11.0, 15.7, 0), Vector3.new(1, 6, 16), Enum.Material.WoodPlanks, Color3.fromRGB(152, 118, 88), 0, nil)
	PrefabUtils.addPart(model, "WallEastUpper", pivot * CFrame.new(11.0, 15.7, 0), Vector3.new(1, 6, 16), Enum.Material.WoodPlanks, Color3.fromRGB(152, 118, 88), 0, nil)

	PrefabUtils.addPart(model, "DoorFrameTop", pivot * CFrame.new(0, 6.6, 10.5), Vector3.new(5.2, 1.6, 1), Enum.Material.Wood, Color3.fromRGB(90, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "DoorFrameLeft", pivot * CFrame.new(-2.6, 4.5, 10.5), Vector3.new(0.9, 5.8, 1), Enum.Material.Wood, Color3.fromRGB(90, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "DoorFrameRight", pivot * CFrame.new(2.6, 4.5, 10.5), Vector3.new(0.9, 5.8, 1), Enum.Material.Wood, Color3.fromRGB(90, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "DoorPanel", pivot * CFrame.new(0, 4.6, 10.6), Vector3.new(4.0, 4.4, 1), Enum.Material.WoodPlanks, Color3.fromRGB(102, 72, 51), 0, nil)

	PrefabUtils.addPart(model, "PorchDeck", pivot * CFrame.new(0, 2.4, 12.4), Vector3.new(11, 0.8, 3.4), Enum.Material.WoodPlanks, Color3.fromRGB(104, 78, 56), 0, nil)
	PrefabUtils.addPart(model, "PorchPostLeft", pivot * CFrame.new(-4.3, 5.6, 12.4), Vector3.new(0.9, 6.2, 0.9), Enum.Material.Wood, Color3.fromRGB(84, 62, 46), 0, nil)
	PrefabUtils.addPart(model, "PorchPostRight", pivot * CFrame.new(4.3, 5.6, 12.4), Vector3.new(0.9, 6.2, 0.9), Enum.Material.Wood, Color3.fromRGB(84, 62, 46), 0, nil)
	PrefabUtils.addPart(model, "PorchAwning", pivot * CFrame.new(0, 9.1, 11.7), Vector3.new(12.6, 0.9, 2.4), Enum.Material.Wood, Color3.fromRGB(101, 77, 58), 0, nil)

	PrefabUtils.addPart(model, "WindowNorthLeft", pivot * CFrame.new(-7.0, 7.2, -10.5), Vector3.new(3.6, 3.4, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowNorthRight", pivot * CFrame.new(7.0, 7.2, -10.5), Vector3.new(3.6, 3.4, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowUpperSouth", pivot * CFrame.new(0, 15.8, 9.1), Vector3.new(3.8, 3.2, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowWest", pivot * CFrame.new(-12.9, 7.2, -3.0), Vector3.new(1, 3.4, 3.2), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowEast", pivot * CFrame.new(12.9, 7.2, 3.0), Vector3.new(1, 3.4, 3.2), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)

	PrefabUtils.addPart(model, "RoofMain", pivot * CFrame.new(0, 19.6, 0), Vector3.new(30, 1.8, 24), Enum.Material.WoodPlanks, Color3.fromRGB(116, 84, 59), 0, nil)
	PrefabUtils.addPart(model, "RoofCap", pivot * CFrame.new(0, 21.5, 0), Vector3.new(22, 1.8, 16), Enum.Material.WoodPlanks, Color3.fromRGB(104, 75, 53), 0, nil)
	PrefabUtils.addPart(model, "RoofDormer", pivot * CFrame.new(0, 23.2, 4.0), Vector3.new(8, 1.4, 6), Enum.Material.WoodPlanks, Color3.fromRGB(101, 74, 52), 0, nil)

	PrefabUtils.addPart(model, "Chimney", pivot * CFrame.new(9.2, 22.4, -6.2), Vector3.new(2.4, 6.8, 2.4), Enum.Material.Rock, Color3.fromRGB(110, 110, 120), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
