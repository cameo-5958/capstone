--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::IncidentCactusFruit",
	Name = "IncidentCactusFruit",
	Biome = "Shared",
	Category = "Nature",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(8, 8),
	HeightStuds = 8,
}

local function markHarvestVisual(part: BasePart)
	part:SetAttribute("HarvestVisual", true)
end

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	model:SetAttribute("HarvestVisualMode", "KeepPrefab")

	PrefabUtils.addPart(model, "PatchBase", pivot * CFrame.new(0, 0.35, 0), Vector3.new(5.0, 0.7, 5.0), Enum.Material.Sand, Color3.fromRGB(184, 154, 104), 0, nil)
	PrefabUtils.addPart(model, "CactusBody", pivot * CFrame.new(0, 2.0, 0), Vector3.new(1.1, 3.8, 1.1), Enum.Material.Grass, Color3.fromRGB(76, 120, 72), 0, nil)
	PrefabUtils.addPart(model, "CactusArmLeft", pivot * CFrame.new(-0.8, 2.5, 0), Vector3.new(0.5, 1.7, 0.5), Enum.Material.Grass, Color3.fromRGB(76, 120, 72), 0, nil)
	PrefabUtils.addPart(model, "CactusArmRight", pivot * CFrame.new(0.8, 2.2, 0.1), Vector3.new(0.5, 1.4, 0.5), Enum.Material.Grass, Color3.fromRGB(76, 120, 72), 0, nil)

	local fruits = {
		PrefabUtils.addPart(model, "FruitA", pivot * CFrame.new(-0.7, 2.9, 0.3), Vector3.new(0.36, 0.52, 0.36), Enum.Material.SmoothPlastic, Color3.fromRGB(210, 92, 88), 0, nil),
		PrefabUtils.addPart(model, "FruitB", pivot * CFrame.new(0.6, 2.4, -0.2), Vector3.new(0.36, 0.52, 0.36), Enum.Material.SmoothPlastic, Color3.fromRGB(196, 82, 78), 0, nil),
	}
	for _, fruit in ipairs(fruits) do
		if fruit then
			markHarvestVisual(fruit)
		end
	end

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
