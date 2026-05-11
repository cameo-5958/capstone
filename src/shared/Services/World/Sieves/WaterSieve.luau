--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local getBiomeMaterials = ctx.getBiomeMaterials

	local waterNoiseX = (seed % 7919) * 0.07
	local waterNoiseZ = (seed % 6361) * 0.05

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		local pondNoise = math.noise((column.X + waterNoiseX) * 0.18, (column.Z + waterNoiseZ) * 0.18, seed * 0.0019)
		local isPondCandidate = pondNoise > 0.48 and column.SurfaceY <= config.BaseY + 3
		if isPondCandidate then
			local materials = getBiomeMaterials(column.Biome)
			column.HasWater = true
			column.SurfaceMaterial = materials.Water
			column.StructureTag = nil
		else
			column.HasWater = false
		end
	end
end
