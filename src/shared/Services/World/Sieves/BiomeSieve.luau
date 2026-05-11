--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local makeColumnKey = ctx.makeColumnKey
	local smoothstep = ctx.smoothstep
	local TerrainTuning = ctx.TerrainTuning

	local function chooseBiomeFromClimate(
		elevationDelta: number,
		temperature: number,
		moisture: number,
		distance01: number
	): string
		local adjustedMoisture = moisture - smoothstep(0.78, 1.0, distance01) * 0.18
		if elevationDelta >= 42 then
			return "Alpine"
		end
		if elevationDelta >= 27 then
			if adjustedMoisture < -0.1 then
				return "HighlandDesert"
			end
			return "PineHighlands"
		end
		if adjustedMoisture > 0.7 then
			return "Marshland"
		end
		if adjustedMoisture > 0.42 and temperature > -0.24 then
			return "DenseForest"
		end
		if adjustedMoisture > 0.22 then
			return "Forest"
		end
		if temperature > 0 and adjustedMoisture < 0.18 then
			return "HighlandDesert"
		end
		return "TemperateGrassland"
	end

		local radius = math.max(config.RadiusTiles, 1)
		local chunkTileSpan = math.max(12, math.floor(TerrainTuning.BiomeChunkTileSpan + 0.5))
		local chunkBlendWidth = math.max(2.5, TerrainTuning.BiomeChunkBlendWidth)
		local climateScale = math.max(0.001, TerrainTuning.BiomeChunkClimateScale)
		local detailScale = math.max(climateScale * 1.8, TerrainTuning.BiomeChunkDetailScale)
		local chunkJitterScale = math.clamp(TerrainTuning.BiomeChunkJitter, 0, 0.49) * chunkTileSpan
		local temperatureNoiseX = (seed % 1999) * 0.12
		local temperatureNoiseZ = (seed % 2999) * 0.1
		local moistureNoiseX = (seed % 4003) * 0.11
		local moistureNoiseZ = (seed % 5003) * 0.09
		local chunkInfoByKey = {} :: { [string]: BiomeChunkInfo }
	
		local processedCount = 0
		for _, column in pairs(columns) do
			if not column.Solid then
				continue
			end
			processedCount += 1
			if processedCount % 1200 == 0 then
				task.wait()
			end
	
			local chunkX = math.floor(column.X / chunkTileSpan)
			local chunkZ = math.floor(column.Z / chunkTileSpan)
			local chunkKey = makeColumnKey(chunkX, chunkZ)
			local info = chunkInfoByKey[chunkKey]
			if not info then
				info = {
					ChunkX = chunkX,
					ChunkZ = chunkZ,
					CenterX = (chunkX + 0.5) * chunkTileSpan,
					CenterZ = (chunkZ + 0.5) * chunkTileSpan,
					SumHeight = 0,
					SumDistance = 0,
					Count = 0,
					AvgHeight = config.BaseY,
					Temperature = 0,
					Moisture = 0,
					Biome = config.Biome,
				}
				chunkInfoByKey[chunkKey] = info
			end
			info.SumHeight += column.SurfaceY
			info.SumDistance += math.clamp(math.sqrt(column.X * column.X + column.Z * column.Z) / radius, 0, 1)
			info.Count += 1
		end
	
		for _, info in pairs(chunkInfoByKey) do
			local baseCenterX = (info.ChunkX + 0.5) * chunkTileSpan
			local baseCenterZ = (info.ChunkZ + 0.5) * chunkTileSpan
			local jitterX = math.noise(
				(info.ChunkX + temperatureNoiseX * 0.013) * 0.79,
				(info.ChunkZ + moistureNoiseX * 0.011) * 0.79,
				seed * 0.00091
			) * chunkJitterScale
			local jitterZ = math.noise(
				(info.ChunkX - temperatureNoiseZ * 0.009) * 0.83,
				(info.ChunkZ + moistureNoiseZ * 0.015) * 0.83,
				seed * 0.00117
			) * chunkJitterScale
			info.CenterX = baseCenterX + jitterX
			info.CenterZ = baseCenterZ + jitterZ
			info.AvgHeight = info.SumHeight / math.max(info.Count, 1)
			local distance01 = info.SumDistance / math.max(info.Count, 1)
			local temperatureMacro = math.noise(
				(info.CenterX + temperatureNoiseX) * climateScale,
				(info.CenterZ + temperatureNoiseZ) * climateScale,
				seed * 0.00053
			)
			local temperatureDetail = math.noise(
				(info.CenterX - moistureNoiseZ) * detailScale,
				(info.CenterZ + moistureNoiseX) * detailScale,
				seed * 0.00147
			)
			local moistureMacro = math.noise(
				(info.CenterX + moistureNoiseX) * climateScale,
				(info.CenterZ + moistureNoiseZ) * climateScale,
				seed * 0.00063
			)
			local moistureDetail = math.noise(
				(info.CenterX - temperatureNoiseZ) * detailScale,
				(info.CenterZ + temperatureNoiseX) * detailScale,
				seed * 0.00131
			)
			local temperature = temperatureMacro * 0.74 + temperatureDetail * 0.26
			local moisture = moistureMacro * 0.72 + moistureDetail * 0.28
			local elevationDelta = info.AvgHeight - config.BaseY
			info.Temperature = temperature
			info.Moisture = moisture
			info.Biome = chooseBiomeFromClimate(elevationDelta, temperature, moisture, distance01)
		end
	
		local function scoreChunkBiomeForColumn(
			column: TileColumn,
			candidate: BiomeChunkInfo,
			home: BiomeChunkInfo,
			localTemperature: number,
			localMoisture: number,
			edgeDistance: number
		): number
			local centerDx = column.X - candidate.CenterX
			local centerDz = column.Z - candidate.CenterZ
			local centerDistance = math.sqrt(centerDx * centerDx + centerDz * centerDz)
			local centerScore = 1 - smoothstep(chunkTileSpan * 0.2, chunkTileSpan * 1.2, centerDistance)
			local elevationDifference = math.abs(candidate.AvgHeight - column.SurfaceY)
			local elevationScore = 1 - smoothstep(5, 24, elevationDifference)
			local climateDifference = math.abs(candidate.Temperature - localTemperature) * 0.8
				+ math.abs(candidate.Moisture - localMoisture) * 1.05
			local climateScore = 1 - smoothstep(0.14, 0.96, climateDifference)
			local edgeAlpha = 1 - smoothstep(0, chunkBlendWidth, edgeDistance)
			local score = centerScore * 2.2 + elevationScore * 0.95 + climateScore * 0.8
			if candidate == home then
				score *= 1.12 - edgeAlpha * 0.34
				score += 1.45
			else
				score *= 0.85 + edgeAlpha * 0.55
				if candidate.Biome == home.Biome then
					score += 0.35
				end
			end
			if candidate.Biome == "Alpine" and (column.SurfaceY - config.BaseY) < 16 then
				score *= 0.78
			elseif candidate.Biome == "Marshland" and (column.SurfaceY - config.BaseY) > 18 then
				score *= 0.72
			end
			return score
		end
	
		processedCount = 0
		for _, column in pairs(columns) do
			if not column.Solid then
				continue
			end
			processedCount += 1
			if processedCount % 900 == 0 then
				task.wait()
			end
	
			local chunkX = math.floor(column.X / chunkTileSpan)
			local chunkZ = math.floor(column.Z / chunkTileSpan)
			local homeChunk = chunkInfoByKey[makeColumnKey(chunkX, chunkZ)]
			if not homeChunk then
				column.Biome = config.Biome
				continue
			end
	
			local relativeX = (column.X / chunkTileSpan) - chunkX
			local relativeZ = (column.Z / chunkTileSpan) - chunkZ
			local edgeDistance = math.min(relativeX, 1 - relativeX, relativeZ, 1 - relativeZ) * chunkTileSpan
			if edgeDistance >= chunkBlendWidth then
				column.Biome = homeChunk.Biome
				continue
			end
	
			local distance01 = math.clamp(math.sqrt(column.X * column.X + column.Z * column.Z) / radius, 0, 1)
			local temperatureMacro = math.noise(
				(column.X + temperatureNoiseX) * climateScale,
				(column.Z + temperatureNoiseZ) * climateScale,
				seed * 0.00053
			)
			local temperatureDetail = math.noise(
				(column.X - moistureNoiseZ) * detailScale,
				(column.Z + moistureNoiseX) * detailScale,
				seed * 0.00147
			)
			local moistureMacro = math.noise(
				(column.X + moistureNoiseX) * climateScale,
				(column.Z + moistureNoiseZ) * climateScale,
				seed * 0.00063
			)
			local moistureDetail = math.noise(
				(column.X - temperatureNoiseZ) * detailScale,
				(column.Z + temperatureNoiseX) * detailScale,
				seed * 0.00131
			)
			local localTemperature = temperatureMacro * 0.74 + temperatureDetail * 0.26
			local localMoisture = moistureMacro * 0.72 + moistureDetail * 0.28 - smoothstep(0.78, 1.0, distance01) * 0.18
	
			local bestBiome = homeChunk.Biome
			local bestScore = -math.huge
			for dx = -1, 1 do
				for dz = -1, 1 do
					local candidate = chunkInfoByKey[makeColumnKey(chunkX + dx, chunkZ + dz)]
					if candidate then
						local score = scoreChunkBiomeForColumn(
							column,
							candidate,
							homeChunk,
							localTemperature,
							localMoisture,
							edgeDistance
						)
						if score > bestScore then
							bestScore = score
							bestBiome = candidate.Biome
						end
					end
				end
			end
			column.Biome = bestBiome
		end
end
