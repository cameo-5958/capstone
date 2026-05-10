--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::LanternPostIron",
	Name = "LanternPostIron",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(8, 8),
	HeightStuds = 18,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "BasePlinth", pivot * CFrame.new(0, 1, 0), Vector3.new(4, 2, 4), Enum.Material.Slate, Color3.fromRGB(102, 104, 114), 0, nil)
	PrefabUtils.addPart(model, "StemLower", pivot * CFrame.new(0, 5, 0), Vector3.new(1, 6, 1), Enum.Material.Metal, Color3.fromRGB(74, 79, 88), 0, nil)
	PrefabUtils.addPart(model, "StemUpper", pivot * CFrame.new(0, 11, 0), Vector3.new(1, 6, 1), Enum.Material.Metal, Color3.fromRGB(74, 79, 88), 0, nil)

	PrefabUtils.addPart(model, "CrossBeam", pivot * CFrame.new(0, 13.5, 0), Vector3.new(6, 1, 1), Enum.Material.Metal, Color3.fromRGB(70, 74, 82), 0, nil)
	PrefabUtils.addPart(model, "ArmWest", pivot * CFrame.new(-3, 13, 0), Vector3.new(1, 2, 1), Enum.Material.Metal, Color3.fromRGB(70, 74, 82), 0, nil)
	PrefabUtils.addPart(model, "ArmEast", pivot * CFrame.new(3, 13, 0), Vector3.new(1, 2, 1), Enum.Material.Metal, Color3.fromRGB(70, 74, 82), 0, nil)

	PrefabUtils.addPart(model, "LanternWest", pivot * CFrame.new(-3, 11, 0), Vector3.new(2, 3, 2), Enum.Material.Neon, Color3.fromRGB(255, 215, 136), 0.15, nil)
	PrefabUtils.addPart(model, "LanternEast", pivot * CFrame.new(3, 11, 0), Vector3.new(2, 3, 2), Enum.Material.Neon, Color3.fromRGB(255, 215, 136), 0.15, nil)

	PrefabUtils.addPart(model, "Cap", pivot * CFrame.new(0, 15, 0), Vector3.new(3, 1, 3), Enum.Material.Metal, Color3.fromRGB(74, 79, 88), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
