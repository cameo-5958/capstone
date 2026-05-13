--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local islandBiome = config.Biome
	local processedCount = 0
	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end
		processedCount += 1
		if processedCount % 1200 == 0 then
			task.wait()
		end
		column.Biome = islandBiome
	end
end
