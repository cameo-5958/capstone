--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::TreasureMarkerBox",
	Name = "TreasureMarkerBox",
	Biome = "Shared",
	Category = "Marker",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(8, 8),
	HeightStuds = 6,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	PrefabUtils.addPart(model, "MarkerBox", pivot * CFrame.new(0, 3.0, 0), Vector3.new(8, 6, 8), Enum.Material.Neon, Color3.fromRGB(255, 210, 72), 0.72, nil)
	PrefabUtils.addPart(model, "MarkerTop", pivot * CFrame.new(0, 6.1, 0), Vector3.new(8, 0.25, 8), Enum.Material.Neon, Color3.fromRGB(255, 235, 128), 0.45, nil)
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
