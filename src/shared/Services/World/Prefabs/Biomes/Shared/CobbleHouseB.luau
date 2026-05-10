--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::CobbleHouseB",
	Name = "CobbleHouseB",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(24, 20),
	HeightStuds = 20,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Foundation", pivot * CFrame.new(0, 1, 0), Vector3.new(22, 2, 18), Enum.Material.Slate, Color3.fromRGB(104, 108, 118), 0, nil)
	PrefabUtils.addPart(model, "Floor", pivot * CFrame.new(0, 2.5, 0), Vector3.new(20, 1, 16), Enum.Material.WoodPlanks, Color3.fromRGB(121, 92, 68), 0, nil)

	PrefabUtils.addPart(model, "WallNorth", pivot * CFrame.new(0, 7, -7.5), Vector3.new(20, 9, 1), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)
	PrefabUtils.addPart(model, "WallSouthLeft", pivot * CFrame.new(-5, 7, 7.5), Vector3.new(10, 9, 1), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)
	PrefabUtils.addPart(model, "WallSouthRight", pivot * CFrame.new(5, 7, 7.5), Vector3.new(10, 9, 1), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)
	PrefabUtils.addPart(model, "WallWest", pivot * CFrame.new(-9.5, 7, 0), Vector3.new(1, 9, 14), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)
	PrefabUtils.addPart(model, "WallEast", pivot * CFrame.new(9.5, 7, 0), Vector3.new(1, 9, 14), Enum.Material.Brick, Color3.fromRGB(164, 154, 141), 0, nil)

	PrefabUtils.addPart(model, "DoorFrameTop", pivot * CFrame.new(0, 6, 7.6), Vector3.new(4, 2, 1), Enum.Material.Wood, Color3.fromRGB(90, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "DoorFrameLeft", pivot * CFrame.new(-2.2, 4, 7.6), Vector3.new(1, 6, 1), Enum.Material.Wood, Color3.fromRGB(90, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "DoorFrameRight", pivot * CFrame.new(2.2, 4, 7.6), Vector3.new(1, 6, 1), Enum.Material.Wood, Color3.fromRGB(90, 64, 45), 0, nil)
	PrefabUtils.addPart(model, "DoorPanel", pivot * CFrame.new(0, 4, 7.7), Vector3.new(3, 4, 1), Enum.Material.WoodPlanks, Color3.fromRGB(102, 72, 51), 0, nil)

	PrefabUtils.addPart(model, "WindowNorthLeft", pivot * CFrame.new(-5, 7, -7.6), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowNorthRight", pivot * CFrame.new(5, 7, -7.6), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowWest", pivot * CFrame.new(-9.6, 7, -2), Vector3.new(1, 3, 3), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowEast", pivot * CFrame.new(9.6, 7, 2), Vector3.new(1, 3, 3), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)

	PrefabUtils.addPart(model, "RoofMain", pivot * CFrame.new(0, 12, 0), Vector3.new(22, 2, 18), Enum.Material.WoodPlanks, Color3.fromRGB(116, 84, 59), 0, nil)
	PrefabUtils.addPart(model, "RoofCap", pivot * CFrame.new(0, 14, 0), Vector3.new(16, 2, 12), Enum.Material.WoodPlanks, Color3.fromRGB(104, 75, 53), 0, nil)
	PrefabUtils.addPart(model, "RoofAwning", pivot * CFrame.new(0, 9, 8.6), Vector3.new(8, 1, 2), Enum.Material.Wood, Color3.fromRGB(101, 77, 58), 0, nil)

	PrefabUtils.addPart(model, "PorchDeck", pivot * CFrame.new(0, 2, 9.5), Vector3.new(8, 1, 3), Enum.Material.WoodPlanks, Color3.fromRGB(104, 78, 56), 0, nil)
	PrefabUtils.addPart(model, "PorchPostLeft", pivot * CFrame.new(-3, 5, 9.5), Vector3.new(1, 6, 1), Enum.Material.Wood, Color3.fromRGB(84, 62, 46), 0, nil)
	PrefabUtils.addPart(model, "PorchPostRight", pivot * CFrame.new(3, 5, 9.5), Vector3.new(1, 6, 1), Enum.Material.Wood, Color3.fromRGB(84, 62, 46), 0, nil)

	PrefabUtils.addPart(model, "Chimney", pivot * CFrame.new(7, 14.5, -5), Vector3.new(2, 7, 2), Enum.Material.Rock, Color3.fromRGB(110, 110, 120), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
