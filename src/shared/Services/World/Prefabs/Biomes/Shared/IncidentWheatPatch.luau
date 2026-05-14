--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::IncidentWheatPatch",
	Name = "IncidentWheatPatch",
	Biome = "Shared",
	Category = "Nature",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(8, 8),
	HeightStuds = 7,
}

local function markHarvestVisual(part: BasePart)
	part:SetAttribute("HarvestVisual", true)
end

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	model:SetAttribute("HarvestVisualMode", "DestroyPrefab")

	PrefabUtils.addPart(model, "PatchBase", pivot * CFrame.new(0, 0.35, 0), Vector3.new(5.2, 0.7, 5.2), Enum.Material.Ground, Color3.fromRGB(132, 118, 86), 0, nil)
	for index, offset in ipairs({
		Vector3.new(-1.0, 1.5, -0.7),
		Vector3.new(-0.2, 1.7, 0.4),
		Vector3.new(0.8, 1.6, -0.2),
		Vector3.new(1.2, 1.8, 0.9),
		Vector3.new(-1.1, 1.65, 1.0),
	}) do
		local stalk = PrefabUtils.addPart(model, "Wheat" .. tostring(index), pivot * CFrame.new(offset), Vector3.new(0.18, 2.2, 0.18), Enum.Material.Grass, Color3.fromRGB(214, 191, 116), 0, nil)
		if stalk then
			markHarvestVisual(stalk)
		end
	end

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
