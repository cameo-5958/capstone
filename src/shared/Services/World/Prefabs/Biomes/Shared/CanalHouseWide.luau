--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::CanalHouseWide",
	Name = "CanalHouseWide",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(28, 18),
	HeightStuds = 19,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Foundation", pivot * CFrame.new(0, 1, 0), Vector3.new(24, 2, 14), Enum.Material.Slate, Color3.fromRGB(105, 108, 117), 0, nil)
	PrefabUtils.addPart(model, "DeckFront", pivot * CFrame.new(0, 2, 7.5), Vector3.new(16, 1, 3), Enum.Material.WoodPlanks, Color3.fromRGB(114, 84, 61), 0, nil)

	PrefabUtils.addPart(model, "WallNorth", pivot * CFrame.new(0, 6.5, -5.5), Vector3.new(20, 8, 1), Enum.Material.Brick, Color3.fromRGB(170, 158, 145), 0, nil)
	PrefabUtils.addPart(model, "WallSouth", pivot * CFrame.new(0, 6.5, 5.5), Vector3.new(20, 8, 1), Enum.Material.Brick, Color3.fromRGB(170, 158, 145), 0, nil)
	PrefabUtils.addPart(model, "WallWest", pivot * CFrame.new(-9.5, 6.5, 0), Vector3.new(1, 8, 10), Enum.Material.Brick, Color3.fromRGB(170, 158, 145), 0, nil)
	PrefabUtils.addPart(model, "WallEast", pivot * CFrame.new(9.5, 6.5, 0), Vector3.new(1, 8, 10), Enum.Material.Brick, Color3.fromRGB(170, 158, 145), 0, nil)

	PrefabUtils.addPart(model, "EntryDoorLeft", pivot * CFrame.new(-1.5, 4.5, 5.6), Vector3.new(2, 5, 1), Enum.Material.WoodPlanks, Color3.fromRGB(95, 69, 48), 0, nil)
	PrefabUtils.addPart(model, "EntryDoorRight", pivot * CFrame.new(1.5, 4.5, 5.6), Vector3.new(2, 5, 1), Enum.Material.WoodPlanks, Color3.fromRGB(95, 69, 48), 0, nil)
	PrefabUtils.addPart(model, "EntryHeader", pivot * CFrame.new(0, 7.2, 5.6), Vector3.new(5, 1, 1), Enum.Material.Wood, Color3.fromRGB(90, 66, 47), 0, nil)

	PrefabUtils.addPart(model, "Roof", pivot * CFrame.new(0, 10.5, 0), Vector3.new(22, 2, 14), Enum.Material.WoodPlanks, Color3.fromRGB(110, 80, 56), 0, nil)
	PrefabUtils.addPart(model, "RoofTop", pivot * CFrame.new(0, 12.5, 0), Vector3.new(14, 2, 8), Enum.Material.WoodPlanks, Color3.fromRGB(100, 73, 52), 0, nil)
	PrefabUtils.addPart(model, "RoofAwning", pivot * CFrame.new(0, 8.9, 6.9), Vector3.new(14, 1, 2), Enum.Material.Wood, Color3.fromRGB(98, 73, 53), 0, nil)

	PrefabUtils.addPart(model, "WindowNorthLeft", pivot * CFrame.new(-5.5, 6.8, -5.6), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(190, 215, 235), 0.2, nil)
	PrefabUtils.addPart(model, "WindowNorthRight", pivot * CFrame.new(5.5, 6.8, -5.6), Vector3.new(3, 3, 1), Enum.Material.SmoothPlastic, Color3.fromRGB(190, 215, 235), 0.2, nil)
	PrefabUtils.addPart(model, "WindowEast", pivot * CFrame.new(9.6, 6.8, 0), Vector3.new(1, 3, 3), Enum.Material.SmoothPlastic, Color3.fromRGB(190, 215, 235), 0.2, nil)

	PrefabUtils.addPart(model, "Chimney", pivot * CFrame.new(-7, 13, -3), Vector3.new(2, 6, 2), Enum.Material.Rock, Color3.fromRGB(112, 113, 123), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
