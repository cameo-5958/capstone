--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

local BiomeSmoothingNeighborOffsets = {
	{ DX = 1, DZ = 0, Weight = 1.5 },
	{ DX = -1, DZ = 0, Weight = 1.5 },
	{ DX = 0, DZ = 1, Weight = 1.5 },
	{ DX = 0, DZ = -1, Weight = 1.5 },
	{ DX = 1, DZ = 1, Weight = 0.95 },
	{ DX = 1, DZ = -1, Weight = 0.95 },
	{ DX = -1, DZ = 1, Weight = 0.95 },
	{ DX = -1, DZ = -1, Weight = 0.95 },
}

return function(ctx, columns, config, seed)
	local makeColumnKey = ctx.makeColumnKey
	local smoothstep = ctx.smoothstep
	local TerrainTuning = ctx.TerrainTuning

	local radius = math.max(config.RadiusTiles, 1)
	local start = TerrainTuning.BiomeEdgeSmoothingStart
	local ending = TerrainTuning.BiomeEdgeSmoothingEnd
	local passes = math.max(0, TerrainTuning.BiomeSmoothPasses)
	if passes <= 0 then
		return
	end

	for _ = 1, passes do
		local nextBiomeByKey = {} :: { [string]: string }
		local processedCount = 0
		for _, column in pairs(columns) do
			if not column.Solid then
				continue
			end
			processedCount += 1
			if processedCount % 900 == 0 then
				task.wait()
			end

			local north = columns[makeColumnKey(column.X, column.Z - 1)]
			local south = columns[makeColumnKey(column.X, column.Z + 1)]
			local west = columns[makeColumnKey(column.X - 1, column.Z)]
			local east = columns[makeColumnKey(column.X + 1, column.Z)]
			local touchesBiomeBoundary = false
			if north and north.Solid and north.Biome ~= column.Biome then
				touchesBiomeBoundary = true
			elseif south and south.Solid and south.Biome ~= column.Biome then
				touchesBiomeBoundary = true
			elseif west and west.Solid and west.Biome ~= column.Biome then
				touchesBiomeBoundary = true
			elseif east and east.Solid and east.Biome ~= column.Biome then
				touchesBiomeBoundary = true
			end
			if not touchesBiomeBoundary then
				continue
			end

			local scores = {} :: { [string]: number }
			local function addBiomeScore(biome: string, weight: number)
				local current = scores[biome]
				if current == nil then
					scores[biome] = weight
				else
					scores[biome] = current + weight
				end
			end

			addBiomeScore(column.Biome, 2.25)
			for _, offset in ipairs(BiomeSmoothingNeighborOffsets) do
				local neighbor = columns[makeColumnKey(column.X + offset.DX, column.Z + offset.DZ)]
				if neighbor and neighbor.Solid then
					addBiomeScore(neighbor.Biome, offset.Weight)
				end
			end

			local distance01 = math.clamp(math.sqrt(column.X * column.X + column.Z * column.Z) / radius, 0, 1)
			local edgeBlend = smoothstep(start, ending, distance01)
			if edgeBlend > 0.08 then
				local inwardScale = 0.9 - edgeBlend * 0.18
				local inwardX = if column.X >= 0
					then math.floor(column.X * inwardScale + 0.5)
					else math.ceil(column.X * inwardScale - 0.5)
				local inwardZ = if column.Z >= 0
					then math.floor(column.Z * inwardScale + 0.5)
					else math.ceil(column.Z * inwardScale - 0.5)
				local inwardNeighbor = columns[makeColumnKey(inwardX, inwardZ)]
				if inwardNeighbor and inwardNeighbor.Solid then
					addBiomeScore(inwardNeighbor.Biome, 1.1 + edgeBlend * 2.3)
				end
			end

			local bestBiome = column.Biome
			local bestScore = -math.huge
			for biomeName, biomeScore in pairs(scores) do
				if biomeScore > bestScore then
					bestBiome = biomeName
					bestScore = biomeScore
				end
			end
			nextBiomeByKey[makeColumnKey(column.X, column.Z)] = bestBiome
		end

		if next(nextBiomeByKey) == nil then
			break
		end

		for key, biome in pairs(nextBiomeByKey) do
			local column = columns[key]
			if column and column.Solid then
				column.Biome = biome
			end
		end

		task.wait()
	end
end
