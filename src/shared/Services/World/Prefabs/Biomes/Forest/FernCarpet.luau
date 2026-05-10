--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Forest::FernCarpet",
	Name = "FernCarpet",
	Biome = "Forest",
	Category = "Nature",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(10, 10),
	HeightStuds = 10,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	PrefabUtils.addPart(model, "PatchCore", pivot * CFrame.new(0, 0.6, 0), Vector3.new(6.8, 1.2, 6.8), Enum.Material.Ground, Color3.fromRGB(188, 78, 62), 0, nil)
	PrefabUtils.addPart(model, "TuftA", pivot * CFrame.new(-2.1, 1.4, -1.8), Vector3.new(1.2, 2.7, 1.2), Enum.Material.Grass, Color3.fromRGB(58, 122, 64), 0, nil)
	PrefabUtils.addPart(model, "TuftB", pivot * CFrame.new(1.9, 1.3, -2.4), Vector3.new(1.1, 2.4, 1.1), Enum.Material.Grass, Color3.fromRGB(58, 122, 64), 0, nil)
	PrefabUtils.addPart(model, "TuftC", pivot * CFrame.new(2.4, 1.2, 1.6), Vector3.new(1.0, 2.2, 1.0), Enum.Material.Grass, Color3.fromRGB(58, 122, 64), 0, nil)
	PrefabUtils.addPart(model, "TuftD", pivot * CFrame.new(-1.8, 1.4, 2.3), Vector3.new(1.3, 2.5, 1.3), Enum.Material.Grass, Color3.fromRGB(58, 122, 64), 0, nil)
	PrefabUtils.addPart(model, "FlowerA", pivot * CFrame.new(0.7, 1.1, 0.4), Vector3.new(0.7, 1.5, 0.7), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 78, 62), 0, "Ball")
	PrefabUtils.addPart(model, "FlowerB", pivot * CFrame.new(-0.9, 1.0, -0.5), Vector3.new(0.65, 1.4, 0.65), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 78, 62), 0, "Ball")
	PrefabUtils.addPart(model, "FlowerC", pivot * CFrame.new(1.6, 0.9, -0.8), Vector3.new(0.6, 1.2, 0.6), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 78, 62), 0, "Ball")
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
