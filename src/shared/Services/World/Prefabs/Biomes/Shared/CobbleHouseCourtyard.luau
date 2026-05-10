--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::CobbleHouseCourtyard",
	Name = "CobbleHouseCourtyard",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(30, 24),
	HeightStuds = 22,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Base", pivot * CFrame.new(0, 1, 0), Vector3.new(26, 2, 20), Enum.Material.Slate, Color3.fromRGB(106, 108, 118), 0, nil)
	PrefabUtils.addPart(model, "CourtyardFloor", pivot * CFrame.new(0, 2.5, 5), Vector3.new(20, 1, 8), Enum.Material.Cobblestone, Color3.fromRGB(118, 116, 112), 0, nil)
	PrefabUtils.addPart(model, "InnerHallFloor", pivot * CFrame.new(0, 2.5, -4), Vector3.new(20, 1, 10), Enum.Material.WoodPlanks, Color3.fromRGB(120, 90, 64), 0, nil)

	PrefabUtils.addPart(model, "WallNorth", pivot * CFrame.new(0, 7, -9.5), Vector3.new(20, 9, 1), Enum.Material.Brick, Color3.fromRGB(167, 156, 144), 0, nil)
	PrefabUtils.addPart(model, "WallSouthWest", pivot * CFrame.new(-6, 7, 9.5), Vector3.new(8, 9, 1), Enum.Material.Brick, Color3.fromRGB(167, 156, 144), 0, nil)
	PrefabUtils.addPart(model, "WallSouthEast", pivot * CFrame.new(6, 7, 9.5), Vector3.new(8, 9, 1), Enum.Material.Brick, Color3.fromRGB(167, 156, 144), 0, nil)
	PrefabUtils.addPart(model, "WallWest", pivot * CFrame.new(-9.5, 7, 0), Vector3.new(1, 9, 18), Enum.Material.Brick, Color3.fromRGB(167, 156, 144), 0, nil)
	PrefabUtils.addPart(model, "WallEast", pivot * CFrame.new(9.5, 7, 0), Vector3.new(1, 9, 18), Enum.Material.Brick, Color3.fromRGB(167, 156, 144), 0, nil)

	PrefabUtils.addPart(model, "CourtyardArchTop", pivot * CFrame.new(0, 7, 9.6), Vector3.new(4, 2, 1), Enum.Material.Wood, Color3.fromRGB(95, 68, 48), 0, nil)
	PrefabUtils.addPart(model, "CourtyardArchWest", pivot * CFrame.new(-2.2, 5, 9.6), Vector3.new(1, 6, 1), Enum.Material.Wood, Color3.fromRGB(95, 68, 48), 0, nil)
	PrefabUtils.addPart(model, "CourtyardArchEast", pivot * CFrame.new(2.2, 5, 9.6), Vector3.new(1, 6, 1), Enum.Material.Wood, Color3.fromRGB(95, 68, 48), 0, nil)

	PrefabUtils.addPart(model, "RoofMain", pivot * CFrame.new(0, 12, -4), Vector3.new(22, 2, 14), Enum.Material.WoodPlanks, Color3.fromRGB(112, 82, 58), 0, nil)
	PrefabUtils.addPart(model, "RoofWingWest", pivot * CFrame.new(-8, 11, 5), Vector3.new(6, 2, 8), Enum.Material.WoodPlanks, Color3.fromRGB(104, 76, 54), 0, nil)
	PrefabUtils.addPart(model, "RoofWingEast", pivot * CFrame.new(8, 11, 5), Vector3.new(6, 2, 8), Enum.Material.WoodPlanks, Color3.fromRGB(104, 76, 54), 0, nil)
	PrefabUtils.addPart(model, "RoofCap", pivot * CFrame.new(0, 14, -4), Vector3.new(14, 2, 10), Enum.Material.WoodPlanks, Color3.fromRGB(101, 74, 52), 0, nil)

	PrefabUtils.addPart(model, "WindowNorthA", pivot * CFrame.new(-5, 7, -9.6), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowNorthB", pivot * CFrame.new(5, 7, -9.6), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowWest", pivot * CFrame.new(-9.6, 7, -2), Vector3.new(1, 3, 3), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)
	PrefabUtils.addPart(model, "WindowEast", pivot * CFrame.new(9.6, 7, -2), Vector3.new(1, 3, 3), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 214, 233), 0.2, nil)

	PrefabUtils.addPart(model, "CourtyardPlanterA", pivot * CFrame.new(-5, 3, 5), Vector3.new(4, 2, 3), Enum.Material.Ground, Color3.fromRGB(98, 82, 66), 0, nil)
	PrefabUtils.addPart(model, "CourtyardPlanterB", pivot * CFrame.new(5, 3, 5), Vector3.new(4, 2, 3), Enum.Material.Ground, Color3.fromRGB(98, 82, 66), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
