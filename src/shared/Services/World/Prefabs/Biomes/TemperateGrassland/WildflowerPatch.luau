--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "TemperateGrassland::WildflowerPatch",
	Name = "WildflowerPatch",
	Biome = "TemperateGrassland",
	Category = "Nature",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(10, 10),
	HeightStuds = 10,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	PrefabUtils.addPart(model, "BladeA", pivot * CFrame.new(-2.2, 1.6, -1.8), Vector3.new(0.55, 3.2, 0.55), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeB", pivot * CFrame.new(-0.8, 1.5, -0.4), Vector3.new(0.5, 3.0, 0.5), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeC", pivot * CFrame.new(1.7, 1.7, -1.9), Vector3.new(0.6, 3.4, 0.6), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeD", pivot * CFrame.new(2.1, 1.4, 1.5), Vector3.new(0.5, 2.8, 0.5), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeE", pivot * CFrame.new(-1.7, 1.6, 2.1), Vector3.new(0.55, 3.1, 0.55), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "FlowerStemA", pivot * CFrame.new(0.7, 1.35, 0.4), Vector3.new(0.35, 2.7, 0.35), Enum.Material.Grass, Color3.fromRGB(92, 158, 84), 0, nil)
	PrefabUtils.addPart(model, "FlowerStemB", pivot * CFrame.new(-1.0, 1.25, -0.6), Vector3.new(0.35, 2.5, 0.35), Enum.Material.Grass, Color3.fromRGB(92, 158, 84), 0, nil)
	PrefabUtils.addPart(model, "FlowerStemC", pivot * CFrame.new(1.5, 1.2, -0.9), Vector3.new(0.35, 2.4, 0.35), Enum.Material.Grass, Color3.fromRGB(92, 158, 84), 0, nil)
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
