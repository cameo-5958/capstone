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
	local snapHeight = ctx.snapHeight
	local isMountainBiome = ctx.isMountainBiome
	local TerrainTuning = ctx.TerrainTuning

	local passes = math.max(0, TerrainTuning.SurfaceSmoothPasses)
	if passes <= 0 then
		return
	end

	local radius = math.max(config.RadiusTiles, 1)
	local baseBlend = math.clamp(TerrainTuning.SurfaceSmoothBlend, 0, 1)
	local mountainBlend = math.clamp(TerrainTuning.SurfaceSmoothMountainBlend, 0, 1)
	local coastBoost = math.max(0, TerrainTuning.SurfaceSmoothCoastBoost)
	local pathBlend = math.clamp(TerrainTuning.SurfaceSmoothPathBlend, 0, 1)
	local maxStep = math.max(1, math.floor(TerrainTuning.SurfaceSmoothMaxStep + 0.5))
	local spikeDelta = math.max(1, math.floor(TerrainTuning.SurfaceSmoothSpikeDelta + 0.5))
	local neighborOffsets = {
		{ DX = 1, DZ = 0, Weight = 1.0 },
		{ DX = -1, DZ = 0, Weight = 1.0 },
		{ DX = 0, DZ = 1, Weight = 1.0 },
		{ DX = 0, DZ = -1, Weight = 1.0 },
		{ DX = 1, DZ = 1, Weight = 0.75 },
		{ DX = 1, DZ = -1, Weight = 0.75 },
		{ DX = -1, DZ = 1, Weight = 0.75 },
		{ DX = -1, DZ = -1, Weight = 0.75 },
	}

	for _ = 1, passes do
		local nextSurfaceByKey = {} :: { [string]: number }
		local processedCount = 0
		for key, column in pairs(columns) do
			if not column.Solid then
				continue
			end
			processedCount += 1
			if processedCount % 2500 == 0 then
				task.wait()
			end

			local distance01 = math.clamp(math.sqrt(column.X * column.X + column.Z * column.Z) / radius, 0, 1)
			local blend = if isMountainBiome(column.Biome) then mountainBlend else baseBlend
			if column.IsPath then
				blend = math.max(blend, pathBlend)
			end
			if not isMountainBiome(column.Biome) then
				local coastAlpha = smoothstep(0.66, 1.0, distance01)
				blend = math.clamp(blend + coastAlpha * coastBoost, 0, 1)
			end

			local selfWeight = if isMountainBiome(column.Biome) then 3.1 else 2.5
			local sum = column.SurfaceY * selfWeight
			local weight = selfWeight
			local neighborCount = 0
			local minNeighbor = math.huge
			local maxNeighbor = -math.huge

			for _, offset in ipairs(neighborOffsets) do
				local neighbor = columns[makeColumnKey(column.X + offset.DX, column.Z + offset.DZ)]
				if neighbor and neighbor.Solid then
					local localWeight = offset.Weight
					if column.IsPath and neighbor.IsPath then
						localWeight *= 1.18
					elseif column.IsPath ~= neighbor.IsPath then
						localWeight *= 0.92
					end
					sum += neighbor.SurfaceY * localWeight
					weight += localWeight
					neighborCount += 1
					if neighbor.SurfaceY < minNeighbor then
						minNeighbor = neighbor.SurfaceY
					end
					if neighbor.SurfaceY > maxNeighbor then
						maxNeighbor = neighbor.SurfaceY
					end
				end
			end

			if neighborCount < 3 then
				nextSurfaceByKey[key] = column.SurfaceY
				continue
			end

			local averagedY = sum / weight
			local blendedY = column.SurfaceY * (1 - blend) + averagedY * blend
			local nextY = snapHeight(blendedY)

			if column.SurfaceY + spikeDelta <= minNeighbor then
				nextY = math.max(nextY, minNeighbor - 1)
			elseif column.SurfaceY - spikeDelta >= maxNeighbor then
				nextY = math.min(nextY, maxNeighbor + 1)
			end

			nextY = math.clamp(nextY, column.SurfaceY - maxStep, column.SurfaceY + maxStep)
			local minSurfaceY = column.BottomY + 2
			if nextY < minSurfaceY then
				nextY = minSurfaceY
			end
			nextSurfaceByKey[key] = nextY
		end

		for key, nextY in pairs(nextSurfaceByKey) do
			local column = columns[key]
			if column and column.Solid then
				column.SurfaceY = nextY
			end
		end
		task.wait()
	end
end
