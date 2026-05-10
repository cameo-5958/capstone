--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Marshland::DriftwoodStack",
	Name = "DriftwoodStack",
	Biome = "Marshland",
	Category = "Nature",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(10, 10),
	HeightStuds = 19,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	PrefabUtils.addPart(model, "LogMain", pivot * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(18), 0), Vector3.new(8.8, 1.7, 2.2), Enum.Material.Wood, Color3.fromRGB(86, 64, 48), 0, "Cylinder")
	PrefabUtils.addPart(model, "LogEndA", pivot * CFrame.new(-3.8, 1.2, -1.0), Vector3.new(1.8, 1.8, 1.8), Enum.Material.Wood, Color3.fromRGB(86, 64, 48), 0, "Ball")
	PrefabUtils.addPart(model, "LogEndB", pivot * CFrame.new(3.8, 1.2, 1.0), Vector3.new(1.8, 1.8, 1.8), Enum.Material.Wood, Color3.fromRGB(86, 64, 48), 0, "Ball")
	PrefabUtils.addPart(model, "MossA", pivot * CFrame.new(-1.6, 2.1, 0.3), Vector3.new(2.8, 0.6, 1.6), Enum.Material.Grass, Color3.fromRGB(78, 112, 82), 0.1, nil)
	PrefabUtils.addPart(model, "MossB", pivot * CFrame.new(1.9, 2.0, -0.4), Vector3.new(2.2, 0.55, 1.5), Enum.Material.Grass, Color3.fromRGB(78, 112, 82), 0.1, nil)
	PrefabUtils.addPart(model, "StumpA", pivot * CFrame.new(-4.2, 1.0, 1.4), Vector3.new(1.4, 2.0, 1.4), Enum.Material.Wood, Color3.fromRGB(86, 64, 48), 0, nil)
	PrefabUtils.addPart(model, "Shrub", pivot * CFrame.new(2.8, 1.3, -2.0), Vector3.new(2.4, 1.8, 2.0), Enum.Material.Grass, Color3.fromRGB(78, 112, 82), 0, "Ball")
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
