--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::EnemySpawnMarkerBox",
	Name = "EnemySpawnMarkerBox",
	Biome = "Shared",
	Category = "Marker",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(10, 10),
	HeightStuds = 7,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	PrefabUtils.addPart(model, "MarkerBox", pivot * CFrame.new(0, 3.5, 0), Vector3.new(10, 7, 10), Enum.Material.Neon, Color3.fromRGB(255, 84, 84), 0.72, nil)
	PrefabUtils.addPart(model, "MarkerTop", pivot * CFrame.new(0, 7.1, 0), Vector3.new(10, 0.25, 10), Enum.Material.Neon, Color3.fromRGB(255, 120, 120), 0.45, nil)
	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
