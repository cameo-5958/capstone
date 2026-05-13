--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local getBiomeMaterials = ctx.getBiomeMaterials

		for _, column in pairs(columns) do
			if not column.Solid then
				continue
			end
	
			local materials = getBiomeMaterials(column.Biome)
			column.FillMaterial = Enum.Material.Rock
			column.SurfaceMaterial = materials.Surface
		end
end
