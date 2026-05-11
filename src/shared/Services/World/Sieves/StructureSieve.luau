--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local PrefabRegistry = ctx.PrefabRegistry
	local RuntimeNatureChanceByBiome = ctx.RuntimeNatureChanceByBiome
	local RuntimeNatureWeightsByBiome = ctx.RuntimeNatureWeightsByBiome
	local chooseWeightedRuntimePrefabId = ctx.chooseWeightedRuntimePrefabId

	local structureRng = Random.new(seed + 4103)

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		if column.HasWater then
			continue
		end

		local distance = math.sqrt(column.X * column.X + column.Z * column.Z)
		if distance > config.RadiusTiles - 2 then
			continue
		end

		column.StructureTag = nil
		local pool = PrefabRegistry.GetRuntimeNaturePool(column.Biome)
		if #pool == 0 then
			continue
		end

		local chance = RuntimeNatureChanceByBiome[column.Biome] or 0.045
		if structureRng:NextNumber() <= chance then
			column.StructureTag =
				chooseWeightedRuntimePrefabId(pool, RuntimeNatureWeightsByBiome[column.Biome], structureRng)
		end
	end
end
