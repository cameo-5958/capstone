--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "HighlandDesert::SaguaroTall",
	Name = "SaguaroTall",
	Biome = "HighlandDesert",
	Category = "Nature",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(12, 12),
	HeightStuds = 16,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	local cactusColor = Color3.fromRGB(98, 134, 78)
	PrefabUtils.addPart(model, "MainStemLower", pivot * CFrame.new(0, 3.2, 0), Vector3.new(1.4, 6.4, 1.4), Enum.Material.Grass, cactusColor, 0, nil)
	PrefabUtils.addPart(model, "MainStemUpper", pivot * CFrame.new(0, 8.0, 0), Vector3.new(1.4, 3.2, 1.4), Enum.Material.Grass, cactusColor, 0, nil)
	PrefabUtils.addPart(model, "ArmLeftBase", pivot * CFrame.new(-1.5, 5.7, 0), Vector3.new(1.0, 1.8, 1.0), Enum.Material.Grass, cactusColor, 0, nil)
	PrefabUtils.addPart(model, "ArmLeftTall", pivot * CFrame.new(-2.1, 7.4, 0), Vector3.new(0.9, 3.8, 0.9), Enum.Material.Grass, cactusColor, 0, nil)
	PrefabUtils.addPart(model, "ArmRightBase", pivot * CFrame.new(1.5, 4.8, 0), Vector3.new(1.0, 1.8, 1.0), Enum.Material.Grass, cactusColor, 0, nil)
	PrefabUtils.addPart(model, "ArmRightTall", pivot * CFrame.new(2.1, 6.2, 0), Vector3.new(0.9, 3.0, 0.9), Enum.Material.Grass, cactusColor, 0, nil)
	PrefabUtils.addPart(model, "MiniCactusA", pivot * CFrame.new(-3.2, 1.6, 2.1), Vector3.new(0.65, 3.2, 0.65), Enum.Material.Grass, cactusColor, 0, nil)
	PrefabUtils.addPart(model, "MiniCactusB", pivot * CFrame.new(2.9, 1.4, -2.2), Vector3.new(0.6, 2.8, 0.6), Enum.Material.Grass, cactusColor, 0, nil)
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
