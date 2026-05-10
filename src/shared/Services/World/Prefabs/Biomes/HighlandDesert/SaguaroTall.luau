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
	PrefabUtils.addPart(model, "TrunkCore", pivot * CFrame.new(0, 4.5, 0), Vector3.new(2.2, 8, 2.2), Enum.Material.Wood, Color3.fromRGB(110, 86, 60), 0, nil)
	PrefabUtils.addPart(model, "RootNorth", pivot * CFrame.new(0, 1.1, -2.3), Vector3.new(2.4, 1.2, 3.2), Enum.Material.Wood, Color3.fromRGB(110, 86, 60), 0, nil)
	PrefabUtils.addPart(model, "RootSouth", pivot * CFrame.new(0, 1.1, 2.3), Vector3.new(2.4, 1.2, 3.2), Enum.Material.Wood, Color3.fromRGB(110, 86, 60), 0, nil)
	PrefabUtils.addPart(model, "RootEast", pivot * CFrame.new(2.3, 1.1, 0), Vector3.new(3.2, 1.2, 2.4), Enum.Material.Wood, Color3.fromRGB(110, 86, 60), 0, nil)
	PrefabUtils.addPart(model, "CanopyCore", pivot * CFrame.new(0, 7, 0), Vector3.new(8.4, 5.2, 8.4), Enum.Material.Grass, Color3.fromRGB(118, 144, 88), 0, "Ball")
	PrefabUtils.addPart(model, "CanopyNorth", pivot * CFrame.new(0, 8, -3.1), Vector3.new(5.1, 3.6, 5.1), Enum.Material.Grass, Color3.fromRGB(118, 144, 88), 0, "Ball")
	PrefabUtils.addPart(model, "CanopySouth", pivot * CFrame.new(0, 8, 3.1), Vector3.new(5.1, 3.6, 5.1), Enum.Material.Grass, Color3.fromRGB(118, 144, 88), 0, "Ball")
	PrefabUtils.addPart(model, "CanopyEast", pivot * CFrame.new(3.1, 7, 0), Vector3.new(4.4, 3.2, 4.4), Enum.Material.Grass, Color3.fromRGB(118, 144, 88), 0, "Ball")
	PrefabUtils.addPart(model, "CanopyWest", pivot * CFrame.new(-3.1, 7, 0), Vector3.new(4.4, 3.2, 4.4), Enum.Material.Grass, Color3.fromRGB(118, 144, 88), 0, "Ball")
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
