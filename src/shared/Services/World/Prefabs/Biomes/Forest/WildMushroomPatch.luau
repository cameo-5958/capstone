--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Forest::WildMushroomPatch",
	Name = "WildMushroomPatch",
	Biome = "Forest",
	Category = "Nature",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(8, 8),
	HeightStuds = 6,
	SpawnMarkers = {
		{
			Id = "Mushrooms",
			Type = "Harvest",
			Offset = Vector3.new(0, 0, 0),
			Harvest = {
				ItemId = "Mushroom",
				QuantityMin = 1,
				QuantityMax = 3,
				PromptActionText = "Gather",
				PromptObjectText = "Mushrooms",
			},
		},
	},
}

local function markHarvestVisual(part: BasePart)
	part:SetAttribute("HarvestVisual", true)
end

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	model:SetAttribute("HarvestVisualMode", "DestroyPrefab")

	PrefabUtils.addPart(model, "PatchBase", pivot * CFrame.new(0, 0.5, 0), Vector3.new(5.6, 1.0, 5.6), Enum.Material.Ground, Color3.fromRGB(88, 96, 72), 0, nil)
	PrefabUtils.addPart(model, "MossA", pivot * CFrame.new(-1.4, 1.0, -0.8), Vector3.new(1.8, 0.8, 1.8), Enum.Material.Grass, Color3.fromRGB(67, 103, 59), 0, nil)
	PrefabUtils.addPart(model, "MossB", pivot * CFrame.new(1.1, 0.9, 0.9), Vector3.new(1.9, 0.8, 1.7), Enum.Material.Grass, Color3.fromRGB(61, 92, 55), 0, nil)

	local stems = {
		PrefabUtils.addPart(model, "StemA", pivot * CFrame.new(-1.0, 1.5, -0.6), Vector3.new(0.35, 1.0, 0.35), Enum.Material.SmoothPlastic, Color3.fromRGB(231, 224, 204), 0, nil),
		PrefabUtils.addPart(model, "StemB", pivot * CFrame.new(0.2, 1.4, -0.1), Vector3.new(0.35, 0.9, 0.35), Enum.Material.SmoothPlastic, Color3.fromRGB(231, 224, 204), 0, nil),
		PrefabUtils.addPart(model, "StemC", pivot * CFrame.new(1.1, 1.6, 0.8), Vector3.new(0.35, 1.1, 0.35), Enum.Material.SmoothPlastic, Color3.fromRGB(231, 224, 204), 0, nil),
	}
	local caps = {
		PrefabUtils.addPart(model, "CapA", pivot * CFrame.new(-1.0, 2.0, -0.6), Vector3.new(1.1, 0.45, 1.1), Enum.Material.SmoothPlastic, Color3.fromRGB(173, 95, 64), 0, nil),
		PrefabUtils.addPart(model, "CapB", pivot * CFrame.new(0.2, 1.9, -0.1), Vector3.new(0.95, 0.4, 0.95), Enum.Material.SmoothPlastic, Color3.fromRGB(196, 114, 79), 0, nil),
		PrefabUtils.addPart(model, "CapC", pivot * CFrame.new(1.1, 2.15, 0.8), Vector3.new(1.2, 0.45, 1.2), Enum.Material.SmoothPlastic, Color3.fromRGB(160, 86, 56), 0, nil),
	}

	for _, part in ipairs(stems) do
		if part then
			markHarvestVisual(part)
		end
	end
	for _, part in ipairs(caps) do
		if part then
			markHarvestVisual(part)
		end
	end

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
