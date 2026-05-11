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

	local thicknessNoiseX = (seed % 4337) * 0.13
	local thicknessNoiseZ = (seed % 3911) * 0.09
	local radius = math.max(config.RadiusTiles, 1)
	local depthRng = Random.new(seed + 9917)
	local anchors = {} :: { DepthAnchor }
	local processedCount = 0

	for _ = 1, TerrainTuning.ThicknessAnchorCount do
		local angle = depthRng:NextNumber(0, math.pi * 2)
		local distance = depthRng:NextNumber(radius * 0.18, radius * 0.82)
		local reach = depthRng:NextNumber(
			radius * TerrainTuning.ThicknessAnchorRadiusMin,
			radius * TerrainTuning.ThicknessAnchorRadiusMax
		)
		local depth = depthRng:NextNumber(TerrainTuning.ThicknessAnchorDepthMin, TerrainTuning.ThicknessAnchorDepthMax)
		table.insert(anchors, {
			X = math.cos(angle) * distance,
			Z = math.sin(angle) * distance,
			Radius = reach,
			Depth = depth,
		})
	end

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end
		processedCount += 1
		if processedCount % 3000 == 0 then
			task.wait()
		end

		local distance01 = math.clamp(math.sqrt(column.X * column.X + column.Z * column.Z) / config.RadiusTiles, 0, 1)
		local centerMass = (1 - distance01)
		local thicknessNoise =
			math.noise((column.X + thicknessNoiseX) * 0.15, (column.Z + thicknessNoiseZ) * 0.15, seed * 0.0013)
		local anchorDepth = 0
		for _, anchor in ipairs(anchors) do
			local dx = column.X - anchor.X
			local dz = column.Z - anchor.Z
			local anchorDistance = math.sqrt(dx * dx + dz * dz)
			local influence = 1
				- smoothstep(anchor.Radius * TerrainTuning.ThicknessAnchorInnerInfluence, anchor.Radius, anchorDistance)
			local candidateDepth = anchor.Depth * (influence * influence)
			if candidateDepth > anchorDepth then
				anchorDepth = candidateDepth
			end
		end

		local thickness = math.max(
			TerrainTuning.ThicknessMin,
			math.floor(
				TerrainTuning.ThicknessBase
					+ centerMass * TerrainTuning.ThicknessCenterScale
					+ thicknessNoise * TerrainTuning.ThicknessNoiseScale
					+ anchorDepth
			)
		)
		column.BottomY = column.SurfaceY - thickness
	end

	local smoothPasses = math.max(0, TerrainTuning.ThicknessSmoothPasses)
	for _ = 1, smoothPasses do
		local nextBottomByKey = {} :: { [string]: number }
		processedCount = 0
		for _, column in pairs(columns) do
			if not column.Solid then
				continue
			end
			processedCount += 1
			if processedCount % 3000 == 0 then
				task.wait()
			end

			local sum = column.BottomY * 2
			local weight = 2
			for dx = -1, 1 do
				for dz = -1, 1 do
					if dx == 0 and dz == 0 then
						continue
					end
					local neighbor = columns[makeColumnKey(column.X + dx, column.Z + dz)]
					if neighbor and neighbor.Solid then
						sum += neighbor.BottomY
						weight += 1
					end
				end
			end

			local smoothedBottom = math.floor(sum / weight + 0.5)
			local maxBottom = column.SurfaceY - TerrainTuning.ThicknessMin
			if smoothedBottom > maxBottom then
				smoothedBottom = maxBottom
			end
			nextBottomByKey[makeColumnKey(column.X, column.Z)] = smoothedBottom
		end

		for key, bottomY in pairs(nextBottomByKey) do
			local column = columns[key]
			if column and column.Solid then
				column.BottomY = bottomY
			end
		end
		task.wait()
	end
end
