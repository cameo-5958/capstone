--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::VillageGateArch",
	Name = "VillageGateArch",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(18, 10),
	HeightStuds = 18,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "PillarWest", pivot * CFrame.new(-6, 6, 0), Vector3.new(4, 12, 4), Enum.Material.Slate, Color3.fromRGB(110, 113, 124), 0, nil)
	PrefabUtils.addPart(model, "PillarEast", pivot * CFrame.new(6, 6, 0), Vector3.new(4, 12, 4), Enum.Material.Slate, Color3.fromRGB(110, 113, 124), 0, nil)
	PrefabUtils.addPart(model, "ArchLintel", pivot * CFrame.new(0, 12, 0), Vector3.new(16, 3, 4), Enum.Material.Slate, Color3.fromRGB(102, 104, 114), 0, nil)
	PrefabUtils.addPart(model, "ArchTop", pivot * CFrame.new(0, 15, 0), Vector3.new(18, 2, 5), Enum.Material.Slate, Color3.fromRGB(96, 99, 109), 0, nil)

	PrefabUtils.addPart(model, "BeamLower", pivot * CFrame.new(0, 11, 0), Vector3.new(12, 1, 1), Enum.Material.Wood, Color3.fromRGB(93, 68, 48), 0, nil)
	PrefabUtils.addPart(model, "Banner", pivot * CFrame.new(0, 9, 0), Vector3.new(10, 4, 1), Enum.Material.Fabric, Color3.fromRGB(181, 64, 50), 0, nil)

	PrefabUtils.addPart(model, "TorchWest", pivot * CFrame.new(-6, 8, 2.6), Vector3.new(1, 2, 1), Enum.Material.Neon, Color3.fromRGB(255, 208, 121), 0.2, nil)
	PrefabUtils.addPart(model, "TorchEast", pivot * CFrame.new(6, 8, 2.6), Vector3.new(1, 2, 1), Enum.Material.Neon, Color3.fromRGB(255, 208, 121), 0.2, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
