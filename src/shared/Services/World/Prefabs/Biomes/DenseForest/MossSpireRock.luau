--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "DenseForest::MossSpireRock",
	Name = "MossSpireRock",
	Biome = "DenseForest",
	Category = "Nature",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(12, 12),
	HeightStuds = 13,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	PrefabUtils.addPart(model, "CoreRock", pivot * CFrame.new(0, 2.2, 0), Vector3.new(6.6, 4.4, 6.6), Enum.Material.Rock, Color3.fromRGB(108, 112, 118), 0, nil)
	PrefabUtils.addPart(model, "NorthRock", pivot * CFrame.new(0, 1.6, -2.6), Vector3.new(4.8, 3.1, 3.6), Enum.Material.Slate, Color3.fromRGB(108, 112, 118), 0, nil)
	PrefabUtils.addPart(model, "EastRock", pivot * CFrame.new(2.8, 1.4, 0.8), Vector3.new(3.2, 2.8, 3.2), Enum.Material.Rock, Color3.fromRGB(108, 112, 118), 0, nil)
	PrefabUtils.addPart(model, "WestRock", pivot * CFrame.new(-2.5, 1.4, -0.6), Vector3.new(3.0, 2.6, 2.8), Enum.Material.Rock, Color3.fromRGB(108, 112, 118), 0, nil)
	PrefabUtils.addPart(model, "PebbleA", pivot * CFrame.new(2.9, 0.7, -2.2), Vector3.new(1.8, 1.2, 1.6), Enum.Material.Slate, Color3.fromRGB(108, 112, 118), 0, nil)
	PrefabUtils.addPart(model, "PebbleB", pivot * CFrame.new(-2.7, 0.7, 2.2), Vector3.new(1.6, 1.1, 1.6), Enum.Material.Slate, Color3.fromRGB(108, 112, 118), 0, nil)
	PrefabUtils.addPart(model, "MossCap", pivot * CFrame.new(0, 3.8, 0), Vector3.new(4.6, 0.6, 4.2), Enum.Material.Grass, Color3.fromRGB(52, 94, 56), 0.05, nil)
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
