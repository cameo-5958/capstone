--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Forest::BerryBush",
	Name = "BerryBush",
	Biome = "Forest",
	Category = "Nature",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(8, 8),
	HeightStuds = 8,
	SpawnMarkers = {
		{
			Id = "Berries",
			Type = "Harvest",
			Offset = Vector3.new(0, 0, 0),
			Harvest = {
				ItemId = "Berries",
				QuantityMin = 2,
				QuantityMax = 4,
				PromptActionText = "Pick",
				PromptObjectText = "Berry Bush",
			},
		},
	},
}

local function markHarvestVisual(part: BasePart)
	part:SetAttribute("HarvestVisual", true)
end

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	model:SetAttribute("HarvestVisualMode", "KeepPrefab")

	PrefabUtils.addPart(model, "PatchBase", pivot * CFrame.new(0, 0.6, 0), Vector3.new(5.8, 1.2, 5.8), Enum.Material.Ground, Color3.fromRGB(91, 113, 74), 0, nil)
	PrefabUtils.addPart(model, "StemA", pivot * CFrame.new(-1.2, 1.7, -0.7), Vector3.new(0.8, 2.0, 0.8), Enum.Material.Wood, Color3.fromRGB(92, 71, 49), 0, nil)
	PrefabUtils.addPart(model, "StemB", pivot * CFrame.new(1.0, 1.8, -0.3), Vector3.new(0.8, 2.1, 0.8), Enum.Material.Wood, Color3.fromRGB(92, 71, 49), 0, nil)
	PrefabUtils.addPart(model, "StemC", pivot * CFrame.new(-0.3, 1.9, 1.1), Vector3.new(0.8, 2.2, 0.8), Enum.Material.Wood, Color3.fromRGB(92, 71, 49), 0, nil)
	PrefabUtils.addPart(model, "LeafMassA", pivot * CFrame.new(-1.3, 2.8, -0.9), Vector3.new(2.4, 2.2, 2.2), Enum.Material.Grass, Color3.fromRGB(56, 104, 58), 0, nil)
	PrefabUtils.addPart(model, "LeafMassB", pivot * CFrame.new(1.1, 2.9, -0.2), Vector3.new(2.6, 2.3, 2.4), Enum.Material.Grass, Color3.fromRGB(58, 112, 60), 0, nil)
	PrefabUtils.addPart(model, "LeafMassC", pivot * CFrame.new(-0.1, 3.0, 1.2), Vector3.new(2.8, 2.4, 2.6), Enum.Material.Grass, Color3.fromRGB(64, 118, 66), 0, nil)
	PrefabUtils.addPart(model, "LeafMassD", pivot * CFrame.new(0.2, 2.5, 0.1), Vector3.new(3.6, 1.8, 3.2), Enum.Material.Grass, Color3.fromRGB(49, 92, 52), 0, nil)

	local berryParts = {
		PrefabUtils.addPart(model, "BerryA", pivot * CFrame.new(-1.1, 2.7, -0.4), Vector3.new(0.45, 0.45, 0.45), Enum.Material.SmoothPlastic, Color3.fromRGB(167, 42, 74), 0, "Ball"),
		PrefabUtils.addPart(model, "BerryB", pivot * CFrame.new(0.8, 2.6, -1.0), Vector3.new(0.45, 0.45, 0.45), Enum.Material.SmoothPlastic, Color3.fromRGB(187, 54, 88), 0, "Ball"),
		PrefabUtils.addPart(model, "BerryC", pivot * CFrame.new(1.2, 2.8, 0.6), Vector3.new(0.45, 0.45, 0.45), Enum.Material.SmoothPlastic, Color3.fromRGB(170, 39, 69), 0, "Ball"),
		PrefabUtils.addPart(model, "BerryD", pivot * CFrame.new(-0.5, 3.1, 1.0), Vector3.new(0.45, 0.45, 0.45), Enum.Material.SmoothPlastic, Color3.fromRGB(196, 62, 92), 0, "Ball"),
		PrefabUtils.addPart(model, "BerryE", pivot * CFrame.new(0.2, 2.9, 0.2), Vector3.new(0.45, 0.45, 0.45), Enum.Material.SmoothPlastic, Color3.fromRGB(176, 45, 79), 0, "Ball"),
	}
	for _, berry in ipairs(berryParts) do
		if berry then
			markHarvestVisual(berry)
		end
	end

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
