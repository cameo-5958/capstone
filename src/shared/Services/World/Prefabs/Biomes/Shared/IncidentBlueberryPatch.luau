--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::IncidentBlueberryPatch",
	Name = "IncidentBlueberryPatch",
	Biome = "Shared",
	Category = "Nature",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(8, 8),
	HeightStuds = 6,
}

local function markHarvestVisual(part: BasePart)
	part:SetAttribute("HarvestVisual", true)
end

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	model:SetAttribute("HarvestVisualMode", "KeepPrefab")

	PrefabUtils.addPart(model, "PatchBase", pivot * CFrame.new(0, 0.45, 0), Vector3.new(4.8, 0.9, 4.8), Enum.Material.Ground, Color3.fromRGB(92, 102, 118), 0, nil)
	PrefabUtils.addPart(model, "LeafMassA", pivot * CFrame.new(-0.9, 1.7, -0.4), Vector3.new(2.2, 1.8, 2.2), Enum.Material.Grass, Color3.fromRGB(70, 112, 84), 0, nil)
	PrefabUtils.addPart(model, "LeafMassB", pivot * CFrame.new(0.8, 1.8, 0.6), Vector3.new(2.4, 1.9, 2.4), Enum.Material.Grass, Color3.fromRGB(78, 120, 91), 0, nil)

	local berries = {
		PrefabUtils.addPart(model, "BerryA", pivot * CFrame.new(-0.8, 1.9, -0.2), Vector3.new(0.38, 0.38, 0.38), Enum.Material.SmoothPlastic, Color3.fromRGB(82, 114, 204), 0, "Ball"),
		PrefabUtils.addPart(model, "BerryB", pivot * CFrame.new(0.2, 2.0, -0.6), Vector3.new(0.38, 0.38, 0.38), Enum.Material.SmoothPlastic, Color3.fromRGB(75, 98, 186), 0, "Ball"),
		PrefabUtils.addPart(model, "BerryC", pivot * CFrame.new(0.9, 1.85, 0.4), Vector3.new(0.38, 0.38, 0.38), Enum.Material.SmoothPlastic, Color3.fromRGB(63, 90, 170), 0, "Ball"),
	}
	for _, berry in ipairs(berries) do
		if berry then
			markHarvestVisual(berry)
		end
	end

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
