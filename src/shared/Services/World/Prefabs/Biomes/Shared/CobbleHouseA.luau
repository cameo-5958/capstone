--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::CobbleHouseA",
	Name = "CobbleHouseA",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(20, 20),
	HeightStuds = 18,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Foundation", pivot * CFrame.new(0, 1, 0), Vector3.new(18, 2, 18), Enum.Material.Slate, Color3.fromRGB(116, 116, 126), 0, nil)
	PrefabUtils.addPart(model, "Floor", pivot * CFrame.new(0, 2.5, 0), Vector3.new(16, 1, 16), Enum.Material.WoodPlanks, Color3.fromRGB(113, 86, 62), 0, nil)

	PrefabUtils.addPart(model, "WallNorth", pivot * CFrame.new(0, 6, -7.5), Vector3.new(16, 7, 1), Enum.Material.Brick, Color3.fromRGB(171, 155, 138), 0, nil)
	PrefabUtils.addPart(model, "WallSouth", pivot * CFrame.new(0, 6, 7.5), Vector3.new(16, 7, 1), Enum.Material.Brick, Color3.fromRGB(171, 155, 138), 0, nil)
	PrefabUtils.addPart(model, "WallWest", pivot * CFrame.new(-7.5, 6, 0), Vector3.new(1, 7, 14), Enum.Material.Brick, Color3.fromRGB(171, 155, 138), 0, nil)
	PrefabUtils.addPart(model, "WallEast", pivot * CFrame.new(7.5, 6, 0), Vector3.new(1, 7, 14), Enum.Material.Brick, Color3.fromRGB(171, 155, 138), 0, nil)

	PrefabUtils.addPart(model, "DoorHeader", pivot * CFrame.new(0, 5, 7.6), Vector3.new(4, 2, 1), Enum.Material.Wood, Color3.fromRGB(90, 63, 42), 0, nil)
	PrefabUtils.addPart(model, "DoorPanel", pivot * CFrame.new(0, 3.5, 7.7), Vector3.new(3, 4, 1), Enum.Material.WoodPlanks, Color3.fromRGB(97, 71, 49), 0, nil)

	PrefabUtils.addPart(model, "RoofMain", pivot * CFrame.new(0, 10.2, 0), Vector3.new(18, 2, 18), Enum.Material.WoodPlanks, Color3.fromRGB(122, 92, 64), 0, nil)
	PrefabUtils.addPart(model, "RoofCap", pivot * CFrame.new(0, 12, 0), Vector3.new(12, 2, 12), Enum.Material.WoodPlanks, Color3.fromRGB(110, 82, 57), 0, nil)

	PrefabUtils.addPart(model, "WindowWest", pivot * CFrame.new(-7.6, 6.5, -3), Vector3.new(1, 3, 3), Enum.Material.SmoothPlastic, Color3.fromRGB(195, 221, 238), 0.25, nil)
	PrefabUtils.addPart(model, "WindowEast", pivot * CFrame.new(7.6, 6.5, 3), Vector3.new(1, 3, 3), Enum.Material.SmoothPlastic, Color3.fromRGB(195, 221, 238), 0.25, nil)

	PrefabUtils.addPart(model, "ChimneyBase", pivot * CFrame.new(5, 12.5, -5), Vector3.new(3, 5, 3), Enum.Material.Rock, Color3.fromRGB(121, 121, 129), 0, nil)
	PrefabUtils.addPart(model, "ChimneyTop", pivot * CFrame.new(5, 15.5, -5), Vector3.new(2, 1, 2), Enum.Material.Rock, Color3.fromRGB(107, 107, 116), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
