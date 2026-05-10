--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::PlazaFountain",
	Name = "PlazaFountain",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(16, 16),
	HeightStuds = 12,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "Base", pivot * CFrame.new(0, 1, 0), Vector3.new(14, 2, 14), Enum.Material.Slate, Color3.fromRGB(115, 117, 127), 0, nil)
	PrefabUtils.addPart(model, "BasinOuter", pivot * CFrame.new(0, 2.5, 0), Vector3.new(12, 1, 12), Enum.Material.Rock, Color3.fromRGB(131, 133, 142), 0, nil)
	PrefabUtils.addPart(model, "WaterSurface", pivot * CFrame.new(0, 3, 0), Vector3.new(10, 1, 10), Enum.Material.Glass, Color3.fromRGB(126, 176, 220), 0.3, nil)

	PrefabUtils.addPart(model, "Pedestal", pivot * CFrame.new(0, 5, 0), Vector3.new(3, 4, 3), Enum.Material.Rock, Color3.fromRGB(120, 122, 131), 0, nil)
	PrefabUtils.addPart(model, "TopBowl", pivot * CFrame.new(0, 7.5, 0), Vector3.new(6, 1, 6), Enum.Material.Rock, Color3.fromRGB(131, 133, 142), 0, nil)
	PrefabUtils.addPart(model, "TopWater", pivot * CFrame.new(0, 8, 0), Vector3.new(4, 1, 4), Enum.Material.Glass, Color3.fromRGB(126, 176, 220), 0.25, nil)
	PrefabUtils.addPart(model, "Spout", pivot * CFrame.new(0, 10, 0), Vector3.new(1, 2, 1), Enum.Material.Neon, Color3.fromRGB(194, 231, 255), 0.1, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
