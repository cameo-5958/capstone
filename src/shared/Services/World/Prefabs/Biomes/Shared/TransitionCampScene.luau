--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)
local CampfirePrefab = require(script.Parent.NodeFenceCamp)
local TreePrefab = require(script.Parent.Parent.PineHighlands.HighlandPineTall)

local Definition = {
	Id = "Shared::TransitionCampScene",
	Name = "TransitionCampScene",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(72, 72),
	HeightStuds = 28,
}

local TREE_RING_OFFSETS = {
	{ -3, -3 },
	{ 0, -3 },
	{ 3, -3 },
	{ -3, 0 },
	{ 3, 0 },
	{ -3, 3 },
	{ 0, 3 },
	{ 3, 3 },
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)
	local tileSize = math.max(4, context.TileSize)
	local centerPosition = pivot.Position

	for x = -2, 2 do
		for z = -2, 2 do
			local tileColor = if math.abs(x) == 2 or math.abs(z) == 2
				then Color3.fromRGB(98, 124, 81)
				else Color3.fromRGB(86, 138, 74)
			PrefabUtils.addPart(
				model,
				string.format("CampTile_%d_%d", x, z),
				pivot * CFrame.new(x * tileSize, 0.5, z * tileSize),
				Vector3.new(tileSize, 1, tileSize),
				Enum.Material.Grass,
				tileColor,
				0,
				nil
			)
		end
	end

	CampfirePrefab.Build(model, {
		Position = centerPosition,
		TileSize = tileSize,
		SurfaceY = centerPosition.Y,
		Biome = "Shared",
		Seed = context.Seed,
		NameSuffix = "Campfire",
	})

	for index, offset in ipairs(TREE_RING_OFFSETS) do
		TreePrefab.Build(model, {
			Position = centerPosition + Vector3.new(offset[1] * tileSize, 0, offset[2] * tileSize),
			TileSize = tileSize,
			SurfaceY = centerPosition.Y,
			Biome = "PineHighlands",
			Seed = (context.Seed or 0) + index,
			NameSuffix = string.format("Tree_%d", index),
		})
	end

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
