--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "TemperateGrassland::StoneWellFence",
	Name = "StoneWellFence",
	Biome = "TemperateGrassland",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(18, 18),
	HeightStuds = 17,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	PrefabUtils.addPart(model, "Foundation", pivot * CFrame.new(0, 0.5, 0), Vector3.new(14, 1, 14), Enum.Material.Slate, Color3.fromRGB(122, 122, 130), 0, nil)
	PrefabUtils.addPart(model, "Floor", pivot * CFrame.new(0, 1.35, 0), Vector3.new(12.6, 0.7, 12.6), Enum.Material.WoodPlanks, Color3.fromRGB(92, 66, 45), 0, nil)
	PrefabUtils.addPart(model, "WallNorth", pivot * CFrame.new(0, 4.0, -5.8), Vector3.new(12.0, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(92, 66, 45), 0, nil)
	PrefabUtils.addPart(model, "WallSouth", pivot * CFrame.new(0, 4.0, 5.8), Vector3.new(12.0, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(92, 66, 45), 0, nil)
	PrefabUtils.addPart(model, "WallWest", pivot * CFrame.new(-5.8, 4.0, 0), Vector3.new(0.8, 5.2, 10.8), Enum.Material.Wood, Color3.fromRGB(92, 66, 45), 0, nil)
	PrefabUtils.addPart(model, "WallEast", pivot * CFrame.new(5.8, 4.0, 0), Vector3.new(0.8, 5.2, 10.8), Enum.Material.Wood, Color3.fromRGB(92, 66, 45), 0, nil)
	PrefabUtils.addPart(model, "DoorFrame", pivot * CFrame.new(0, 2.4, 5.9), Vector3.new(2.8, 3.8, 0.4), Enum.Material.WoodPlanks, Color3.fromRGB(132, 94, 66), 0, nil)
	PrefabUtils.addPart(model, "RoofBase", pivot * CFrame.new(0, 6.9, 0), Vector3.new(13.2, 1.1, 13.2), Enum.Material.WoodPlanks, Color3.fromRGB(132, 94, 66), 0, nil)
	PrefabUtils.addPart(model, "RoofCap", pivot * CFrame.new(0, 8.0, 0), Vector3.new(10.0, 1.1, 10.0), Enum.Material.WoodPlanks, Color3.fromRGB(132, 94, 66), 0, nil)
	PrefabUtils.addPart(model, "WindowNorth", pivot * CFrame.new(-3.2, 4.1, -5.75), Vector3.new(2.0, 1.8, 0.2), Enum.Material.SmoothPlastic, Color3.fromRGB(203, 184, 120), 0.25, nil)
	PrefabUtils.addPart(model, "WindowEast", pivot * CFrame.new(5.75, 4.1, -2.6), Vector3.new(0.2, 1.8, 2.0), Enum.Material.SmoothPlastic, Color3.fromRGB(203, 184, 120), 0.25, nil)
	PrefabUtils.addPart(model, "ChimneyBase", pivot * CFrame.new(3.8, 8.2, -3.8), Vector3.new(1.8, 4.4, 1.8), Enum.Material.Rock, Color3.fromRGB(122, 122, 130), 0, nil)
	PrefabUtils.addPart(model, "EntrySteps", pivot * CFrame.new(0, 0.55, 7.1), Vector3.new(3.8, 0.6, 2.2), Enum.Material.Sandstone, Color3.fromRGB(122, 122, 130), 0, nil)
	PrefabUtils.addPart(model, "FenceNorth", pivot * CFrame.new(0, 1.6, -7.1), Vector3.new(14.2, 1.0, 0.45), Enum.Material.Wood, Color3.fromRGB(92, 66, 45), 0, nil)
	PrefabUtils.addPart(model, "FenceSouth", pivot * CFrame.new(0, 1.6, 7.1), Vector3.new(14.2, 1.0, 0.45), Enum.Material.Wood, Color3.fromRGB(92, 66, 45), 0, nil)
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
