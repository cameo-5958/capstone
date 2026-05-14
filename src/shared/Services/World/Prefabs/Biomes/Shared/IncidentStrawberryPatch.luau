--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::IncidentStrawberryPatch",
	Name = "IncidentStrawberryPatch",
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

	PrefabUtils.addPart(model, "PatchBase", pivot * CFrame.new(0, 0.45, 0), Vector3.new(4.8, 0.9, 4.8), Enum.Material.Ground, Color3.fromRGB(114, 100, 92), 0, nil)
	PrefabUtils.addPart(model, "LeafMassA", pivot * CFrame.new(-0.7, 1.6, -0.5), Vector3.new(2.1, 1.7, 2.1), Enum.Material.Grass, Color3.fromRGB(82, 122, 76), 0, nil)
	PrefabUtils.addPart(model, "LeafMassB", pivot * CFrame.new(0.9, 1.7, 0.5), Vector3.new(2.3, 1.8, 2.3), Enum.Material.Grass, Color3.fromRGB(88, 130, 80), 0, nil)

	local berries = {
		PrefabUtils.addPart(model, "BerryA", pivot * CFrame.new(-0.9, 1.8, -0.1), Vector3.new(0.32, 0.42, 0.32), Enum.Material.SmoothPlastic, Color3.fromRGB(202, 64, 74), 0, nil),
		PrefabUtils.addPart(model, "BerryB", pivot * CFrame.new(0.1, 1.9, -0.5), Vector3.new(0.32, 0.42, 0.32), Enum.Material.SmoothPlastic, Color3.fromRGB(188, 58, 67), 0, nil),
		PrefabUtils.addPart(model, "BerryC", pivot * CFrame.new(0.8, 1.75, 0.5), Vector3.new(0.32, 0.42, 0.32), Enum.Material.SmoothPlastic, Color3.fromRGB(210, 72, 80), 0, nil),
	}
	for _, berry in ipairs(berries) do
		if berry then
			markHarvestVisual(berry)
		end
	end

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
