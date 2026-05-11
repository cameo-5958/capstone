--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::CobbleHouseA",
	Name = "CobbleHouseA",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(30, 28),
	HeightStuds = 28,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Foundation", pivot * CFrame.new(0, 1, 0), Vector3.new(26, 2, 24), Enum.Material.Slate, Color3.fromRGB(116, 116, 126), 0, nil)
	PrefabUtils.addPart(model, "Plinth", pivot * CFrame.new(0, 2.3, 0), Vector3.new(24, 0.8, 22), Enum.Material.Cobblestone, Color3.fromRGB(127, 125, 120), 0, nil)
	PrefabUtils.addPart(model, "Floor", pivot * CFrame.new(0, 2.9, 0), Vector3.new(22, 0.8, 20), Enum.Material.WoodPlanks, Color3.fromRGB(113, 86, 62), 0, nil)

	PrefabUtils.addPart(model, "WallNorthLower", pivot * CFrame.new(0, 6.8, -9.8), Vector3.new(22, 7, 1), Enum.Material.Brick, Color3.fromRGB(171, 155, 138), 0, nil)
	PrefabUtils.addPart(model, "WallSouthLower", pivot * CFrame.new(0, 6.8, 9.8), Vector3.new(22, 7, 1), Enum.Material.Brick, Color3.fromRGB(171, 155, 138), 0, nil)
	PrefabUtils.addPart(model, "WallWestLower", pivot * CFrame.new(-10.8, 6.8, 0), Vector3.new(1, 7, 18), Enum.Material.Brick, Color3.fromRGB(171, 155, 138), 0, nil)
	PrefabUtils.addPart(model, "WallEastLower", pivot * CFrame.new(10.8, 6.8, 0), Vector3.new(1, 7, 18), Enum.Material.Brick, Color3.fromRGB(171, 155, 138), 0, nil)

	PrefabUtils.addPart(model, "BeltNorth", pivot * CFrame.new(0, 9.9, -9.8), Vector3.new(22, 0.8, 1), Enum.Material.Wood, Color3.fromRGB(90, 63, 42), 0, nil)
	PrefabUtils.addPart(model, "BeltSouth", pivot * CFrame.new(0, 9.9, 9.8), Vector3.new(22, 0.8, 1), Enum.Material.Wood, Color3.fromRGB(90, 63, 42), 0, nil)
	PrefabUtils.addPart(model, "BeltWest", pivot * CFrame.new(-10.8, 9.9, 0), Vector3.new(1, 0.8, 18), Enum.Material.Wood, Color3.fromRGB(90, 63, 42), 0, nil)
	PrefabUtils.addPart(model, "BeltEast", pivot * CFrame.new(10.8, 9.9, 0), Vector3.new(1, 0.8, 18), Enum.Material.Wood, Color3.fromRGB(90, 63, 42), 0, nil)

	PrefabUtils.addPart(model, "WallNorthUpper", pivot * CFrame.new(0, 13.6, -9.8), Vector3.new(20, 5, 1), Enum.Material.WoodPlanks, Color3.fromRGB(153, 118, 87), 0, nil)
	PrefabUtils.addPart(model, "WallSouthUpper", pivot * CFrame.new(0, 13.6, 9.8), Vector3.new(20, 5, 1), Enum.Material.WoodPlanks, Color3.fromRGB(153, 118, 87), 0, nil)
	PrefabUtils.addPart(model, "WallWestUpper", pivot * CFrame.new(-10.8, 13.6, 0), Vector3.new(1, 5, 16), Enum.Material.WoodPlanks, Color3.fromRGB(153, 118, 87), 0, nil)
	PrefabUtils.addPart(model, "WallEastUpper", pivot * CFrame.new(10.8, 13.6, 0), Vector3.new(1, 5, 16), Enum.Material.WoodPlanks, Color3.fromRGB(153, 118, 87), 0, nil)

	PrefabUtils.addPart(model, "PorchDeck", pivot * CFrame.new(0, 2.6, 11.9), Vector3.new(10, 0.8, 3.2), Enum.Material.WoodPlanks, Color3.fromRGB(104, 78, 56), 0, nil)
	PrefabUtils.addPart(model, "PorchPostLeft", pivot * CFrame.new(-4.2, 5.6, 11.9), Vector3.new(0.9, 6, 0.9), Enum.Material.Wood, Color3.fromRGB(84, 62, 46), 0, nil)
	PrefabUtils.addPart(model, "PorchPostRight", pivot * CFrame.new(4.2, 5.6, 11.9), Vector3.new(0.9, 6, 0.9), Enum.Material.Wood, Color3.fromRGB(84, 62, 46), 0, nil)
	PrefabUtils.addPart(model, "PorchAwning", pivot * CFrame.new(0, 8.9, 11.3), Vector3.new(11.2, 0.9, 2.2), Enum.Material.WoodPlanks, Color3.fromRGB(101, 77, 58), 0, nil)

	PrefabUtils.addPart(model, "DoorHeader", pivot * CFrame.new(0, 6.2, 9.9), Vector3.new(5.2, 1.6, 1), Enum.Material.Wood, Color3.fromRGB(90, 63, 42), 0, nil)
	PrefabUtils.addPart(model, "DoorPanel", pivot * CFrame.new(0, 4.2, 10.0), Vector3.new(3.6, 4.2, 1), Enum.Material.WoodPlanks, Color3.fromRGB(97, 71, 49), 0, nil)

	PrefabUtils.addPart(model, "WindowNorthLeft", pivot * CFrame.new(-6.0, 6.8, -9.9), Vector3.new(3.2, 3.2, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(195, 221, 238), 0.25, nil)
	PrefabUtils.addPart(model, "WindowNorthRight", pivot * CFrame.new(6.0, 6.8, -9.9), Vector3.new(3.2, 3.2, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(195, 221, 238), 0.25, nil)
	PrefabUtils.addPart(model, "WindowEast", pivot * CFrame.new(10.9, 7.0, 2.8), Vector3.new(1, 3.2, 3.0), Enum.Material.SmoothPlastic, Color3.fromRGB(195, 221, 238), 0.25, nil)
	PrefabUtils.addPart(model, "WindowWest", pivot * CFrame.new(-10.9, 7.0, -2.8), Vector3.new(1, 3.2, 3.0), Enum.Material.SmoothPlastic, Color3.fromRGB(195, 221, 238), 0.25, nil)

	PrefabUtils.addPart(model, "RoofMain", pivot * CFrame.new(0, 17.4, 0), Vector3.new(26, 1.8, 24), Enum.Material.WoodPlanks, Color3.fromRGB(122, 92, 64), 0, nil)
	PrefabUtils.addPart(model, "RoofCap", pivot * CFrame.new(0, 19.2, 0), Vector3.new(18, 1.8, 16), Enum.Material.WoodPlanks, Color3.fromRGB(110, 82, 57), 0, nil)
	PrefabUtils.addPart(model, "RoofRidge", pivot * CFrame.new(0, 20.4, 0), Vector3.new(8, 0.8, 14), Enum.Material.Wood, Color3.fromRGB(93, 69, 49), 0, nil)

	PrefabUtils.addPart(model, "ChimneyBase", pivot * CFrame.new(7.3, 19.2, -6.2), Vector3.new(2.6, 5.4, 2.6), Enum.Material.Rock, Color3.fromRGB(121, 121, 129), 0, nil)
	PrefabUtils.addPart(model, "ChimneyTop", pivot * CFrame.new(7.3, 22.0, -6.2), Vector3.new(2.0, 0.9, 2.0), Enum.Material.Rock, Color3.fromRGB(107, 107, 116), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
