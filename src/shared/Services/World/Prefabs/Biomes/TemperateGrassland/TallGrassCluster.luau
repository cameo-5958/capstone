--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "TemperateGrassland::TallGrassCluster",
	Name = "TallGrassCluster",
	Biome = "TemperateGrassland",
	Category = "Nature",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(12, 12),
	HeightStuds = 13,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	PrefabUtils.addPart(model, "BladeA", pivot * CFrame.new(-2.3, 1.6, -1.9), Vector3.new(0.6, 3.2, 0.6), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeB", pivot * CFrame.new(-1.0, 1.4, -0.7), Vector3.new(0.55, 2.8, 0.55), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeC", pivot * CFrame.new(1.2, 1.7, -2.1), Vector3.new(0.6, 3.4, 0.6), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeD", pivot * CFrame.new(2.3, 1.5, -0.8), Vector3.new(0.55, 3.0, 0.55), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeE", pivot * CFrame.new(2.0, 1.5, 1.4), Vector3.new(0.55, 3.1, 0.55), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeF", pivot * CFrame.new(-1.8, 1.6, 2.2), Vector3.new(0.6, 3.3, 0.6), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	PrefabUtils.addPart(model, "BladeG", pivot * CFrame.new(0.4, 1.3, 0.6), Vector3.new(0.5, 2.6, 0.5), Enum.Material.Grass, Color3.fromRGB(76, 140, 72), 0, nil)
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
