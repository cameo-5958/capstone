--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local StructureFlatteningSettings = ctx.StructureFlatteningSettings
	local PrefabRegistry = ctx.PrefabRegistry
	local getRuntimeStructureScale = ctx.getRuntimeStructureScale
	local snapHeight = ctx.snapHeight
	local smoothstep = ctx.smoothstep
	local makeColumnKey = ctx.makeColumnKey

		if not StructureFlatteningSettings.Enabled then
			return
		end
	
		local maxHalfFootprintTiles = math.max(1, math.floor(StructureFlatteningSettings.MaxHalfFootprintTiles + 0.5))
		local ringInnerPaddingTiles = math.max(0, math.floor(StructureFlatteningSettings.RingInnerPaddingTiles + 0.5))
		local ringOuterScale = math.max(1.1, StructureFlatteningSettings.RingOuterScale)
		local targetHeightBlend = math.clamp(StructureFlatteningSettings.TargetHeightBlend, 0, 1)
		local smoothingPasses = math.max(0, math.floor(StructureFlatteningSettings.SmoothingPasses + 0.5))
		local smoothingBlend = math.clamp(StructureFlatteningSettings.SmoothingBlend, 0, 1)
		local preservePathCells = StructureFlatteningSettings.PreservePathCells == true
		local forceFlattenEnabled = StructureFlatteningSettings.ForceFlattenEnabled == true
		local forceCorePaddingTiles = math.max(0, math.floor(StructureFlatteningSettings.ForceCorePaddingTiles + 0.5))
		local forceCoreWeight = math.max(1, StructureFlatteningSettings.ForceCoreWeight)
		local forceRingTargetPercentile = math.clamp(StructureFlatteningSettings.ForceRingTargetPercentile, 0, 1)
		local forceClampRisePerTile = math.max(0.1, StructureFlatteningSettings.ForceClampRisePerTile)
		local forceClampRadiusScale = math.max(1, StructureFlatteningSettings.ForceClampRadiusScale)
		local tileSize = math.max(1, config.TileSize)
	
		local influenceByKey = {} :: { [string]: { SumHeight: number, SumWeight: number } }
		local hardTargets = {} :: { [string]: number }
		local structureProfiles = {} :: {
			{
				X: number,
				Z: number,
				CoreHalfX: number,
				CoreHalfZ: number,
				DesiredHeight: number,
				ClampRadius: number,
			}
		}
	
		local function clampFlattenHeight(column: TileColumn, value: number): number
			local nextY = snapHeight(value)
			if nextY > column.SurfaceY then
				nextY = column.SurfaceY
			end
			local minY = column.BottomY + 2
			if nextY < minY then
				nextY = minY
			end
			return nextY
		end
	
		local function addInfluence(key: string, height: number, weight: number)
			local influence = influenceByKey[key]
			if not influence then
				influence = { SumHeight = 0, SumWeight = 0 }
				influenceByKey[key] = influence
			end
			influence.SumHeight += height * weight
			influence.SumWeight += weight
		end
	
		local function addHardTarget(key: string, targetHeight: number)
			local existing = hardTargets[key]
			if existing == nil or targetHeight < existing then
				hardTargets[key] = targetHeight
			end
		end
	
		local function getPercentile(values: { number }, percentile: number): number?
			local count = #values
			if count == 0 then
				return nil
			end
			table.sort(values)
			local index = math.clamp(math.floor((count - 1) * percentile + 1.5), 1, count)
			return values[index]
		end
	
		for _, column in pairs(columns) do
			if not column.Solid or column.HasWater or column.StructureTag == nil then
				continue
			end
	
			local definition = PrefabRegistry.GetById(column.StructureTag)
			if not definition or definition.Category ~= "Structure" then
				continue
			end
	
			local structureScale = getRuntimeStructureScale(definition)
			local scaledFootprintStudsX = definition.FootprintStuds.X * structureScale
			local scaledFootprintStudsZ = definition.FootprintStuds.Y * structureScale
			local footprintHalfX = math.max(1, math.ceil((scaledFootprintStudsX * 0.5) / tileSize))
			local footprintHalfZ = math.max(1, math.ceil((scaledFootprintStudsZ * 0.5) / tileSize))
			footprintHalfX = math.min(maxHalfFootprintTiles, footprintHalfX)
			footprintHalfZ = math.min(maxHalfFootprintTiles, footprintHalfZ)
	
			local coreHalfX = math.min(maxHalfFootprintTiles, footprintHalfX + forceCorePaddingTiles)
			local coreHalfZ = math.min(maxHalfFootprintTiles, footprintHalfZ + forceCorePaddingTiles)
			local ringCoreRadius = math.max(coreHalfX, coreHalfZ)
			local ringInnerRadius = ringCoreRadius + ringInnerPaddingTiles
			local ringOuterRadius = math.max(ringInnerRadius + 1, math.ceil(ringCoreRadius * ringOuterScale))
	
			local ringSum = 0
			local ringCount = 0
			local ringHeights = {} :: { number }
			for dx = -ringOuterRadius, ringOuterRadius do
				for dz = -ringOuterRadius, ringOuterRadius do
					local distance = math.sqrt(dx * dx + dz * dz)
					if distance >= ringInnerRadius and distance <= ringOuterRadius then
						local ringColumn = columns[makeColumnKey(column.X + dx, column.Z + dz)]
						if ringColumn and ringColumn.Solid then
							ringSum += ringColumn.SurfaceY
							ringCount += 1
							table.insert(ringHeights, ringColumn.SurfaceY)
						end
					end
				end
			end
	
			local desiredHeight = column.SurfaceY
			if ringCount > 0 then
				local ringAverage = ringSum / ringCount
				desiredHeight = column.SurfaceY * targetHeightBlend + ringAverage * (1 - targetHeightBlend)
			end
			if forceFlattenEnabled then
				local ringTarget = getPercentile(ringHeights, forceRingTargetPercentile)
				if ringTarget ~= nil then
					desiredHeight = math.min(desiredHeight, ringTarget)
				end
			end
			desiredHeight = clampFlattenHeight(column, desiredHeight)
	
			table.insert(structureProfiles, {
				X = column.X,
				Z = column.Z,
				CoreHalfX = coreHalfX,
				CoreHalfZ = coreHalfZ,
				DesiredHeight = desiredHeight,
				ClampRadius = math.max(ringOuterRadius, math.ceil(ringCoreRadius * forceClampRadiusScale)),
			})
	
			for dx = -coreHalfX, coreHalfX do
				for dz = -coreHalfZ, coreHalfZ do
					local nx = dx / coreHalfX
					local nz = dz / coreHalfZ
					local radial = math.sqrt(nx * nx + nz * nz)
					if radial <= 1 then
						local candidateKey = makeColumnKey(column.X + dx, column.Z + dz)
						local candidate = columns[candidateKey]
						if candidate and candidate.Solid and not candidate.HasWater then
							if preservePathCells and candidate.IsPath and candidate.StructureTag == nil then
								continue
							end
	
							local alpha = 1 - smoothstep(0, 1, radial)
							if alpha > 0 then
								local weight = if forceFlattenEnabled then alpha * forceCoreWeight else alpha
								addInfluence(candidateKey, desiredHeight, weight)
								if forceFlattenEnabled then
									addHardTarget(candidateKey, desiredHeight)
								end
							end
						end
					end
				end
			end
		end
	
		local flattenedTargets = {} :: { [string]: number }
		for key, influence in pairs(influenceByKey) do
			local column = columns[key]
			if column and column.Solid and influence.SumWeight > 0 then
				local nextY = clampFlattenHeight(column, influence.SumHeight / influence.SumWeight)
				flattenedTargets[key] = nextY
			end
		end
	
		for _ = 1, smoothingPasses do
			local smoothedTargets = {} :: { [string]: number }
			for existingKey, existingY in pairs(flattenedTargets) do
				smoothedTargets[existingKey] = existingY
			end
			for key, currentY in pairs(flattenedTargets) do
				local column = columns[key]
				if not column then
					continue
				end
	
				local sum = currentY * 2
				local weight = 2
				local north = flattenedTargets[makeColumnKey(column.X, column.Z - 1)]
				if north then
					sum += north
					weight += 1
				end
				local south = flattenedTargets[makeColumnKey(column.X, column.Z + 1)]
				if south then
					sum += south
					weight += 1
				end
				local west = flattenedTargets[makeColumnKey(column.X - 1, column.Z)]
				if west then
					sum += west
					weight += 1
				end
				local east = flattenedTargets[makeColumnKey(column.X + 1, column.Z)]
				if east then
					sum += east
					weight += 1
				end
	
				local averagedY = snapHeight(sum / weight)
				local nextY = clampFlattenHeight(column, currentY * (1 - smoothingBlend) + averagedY * smoothingBlend)
				smoothedTargets[key] = nextY
			end
			flattenedTargets = smoothedTargets
		end
	
		if forceFlattenEnabled then
			for key, hardY in pairs(hardTargets) do
				local column = columns[key]
				if column and column.Solid then
					local nextY = clampFlattenHeight(column, hardY)
					local current = flattenedTargets[key] or column.SurfaceY
					flattenedTargets[key] = math.min(current, nextY)
				end
			end
	
			for _, profile in ipairs(structureProfiles) do
				local clampRadius = math.max(1, profile.ClampRadius)
				for dx = -clampRadius, clampRadius do
					for dz = -clampRadius, clampRadius do
						local distance = math.sqrt(dx * dx + dz * dz)
						if distance > clampRadius then
							continue
						end
	
						local key = makeColumnKey(profile.X + dx, profile.Z + dz)
						local column = columns[key]
						if not column or not column.Solid or column.HasWater then
							continue
						end
						if preservePathCells and column.IsPath and column.StructureTag == nil then
							continue
						end
	
						local allowedMax = profile.DesiredHeight + distance * forceClampRisePerTile
						local current = flattenedTargets[key] or column.SurfaceY
						if current > allowedMax then
							flattenedTargets[key] = clampFlattenHeight(column, allowedMax)
						end
					end
				end
			end
		end
	
		for key, height in pairs(flattenedTargets) do
			local column = columns[key]
			if column and column.Solid then
				if preservePathCells and column.IsPath then
					continue
				end
				column.SurfaceY = height
			end
		end
end
