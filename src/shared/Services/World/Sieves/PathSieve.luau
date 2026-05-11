--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local getCenterSolidColumn = ctx.getCenterSolidColumn
	local TerrainTuning = ctx.TerrainTuning
	local randomNodeRadiusScale = ctx.randomNodeRadiusScale
	local getNearestSolidColumnToTarget = ctx.getNearestSolidColumnToTarget
	local angularDistance = ctx.angularDistance
	local hasNodeOverlap = ctx.hasNodeOverlap
	local generateWindingPathNodes = ctx.generateWindingPathNodes
	local getSolidColumnNear = ctx.getSolidColumnNear
	local makeColumnKey = ctx.makeColumnKey
	local smoothstep = ctx.smoothstep
	local snapHeight = ctx.snapHeight
	local isMountainBiome = ctx.isMountainBiome
	local isPlainsBiome = ctx.isPlainsBiome
	local isForestBiome = ctx.isForestBiome
	local RuntimeNodeStructuresEnabled = ctx.RuntimeNodeStructuresEnabled
	local RuntimeNodeAssemblyPlacement = ctx.RuntimeNodeAssemblyPlacement
	local RuntimeNodeAssemblyDefinitions = ctx.RuntimeNodeAssemblyDefinitions
	local chooseWeightedRuntimePrefabId = ctx.chooseWeightedRuntimePrefabId
	local getRuntimeNodeAssemblyPool = ctx.getRuntimeNodeAssemblyPool
	local getRuntimeNodePool = ctx.getRuntimeNodePool
	local getRuntimeStructureScale = ctx.getRuntimeStructureScale
	local getBiomeMaterials = ctx.getBiomeMaterials
	local isHabitationStructureName = ctx.isHabitationStructureName
	local isEnvironmentStructureName = ctx.isEnvironmentStructureName
	local PrefabRegistry = ctx.PrefabRegistry
	local getPathNodeBaseRadiusTiles = ctx.getPathNodeBaseRadiusTiles

	local centerColumn = getCenterSolidColumn(columns)
	if not centerColumn then
		return nil, {}, 0, {}
	end

	local endpointCount = math.max(2, TerrainTuning.PathEndpointCount)
	local nodeMinSpacing = math.max(TerrainTuning.PathNodeSpacing, TerrainTuning.PathNodeMinSpacing)
	local endpointRng = Random.new(seed + 13127)
	local endpoints = {} :: { TileColumn }
	local allRoutes = {} :: { { PathPoint } }
	local radius = math.max(config.RadiusTiles, 1)
	local sideMinDistanceSq = radius * radius * 0.45
	local startColumn = centerColumn
	local startAngle = endpointRng:NextNumber(0, math.pi * 2)
	local startRadius = radius
		* endpointRng:NextNumber(TerrainTuning.PathEndpointRadiusMin, TerrainTuning.PathEndpointRadiusMax)
	local startTargetX = math.cos(startAngle) * startRadius
	local startTargetZ = math.sin(startAngle) * startRadius
	local sideStart =
		getNearestSolidColumnToTarget(columns, startTargetX, startTargetZ, sideMinDistanceSq, centerColumn)
	if sideStart then
		startColumn = sideStart
	else
		local farthestSide: TileColumn? = nil
		local farthestDistanceSq = -1
		for _, column in pairs(columns) do
			if column.Solid and not column.HasWater then
				local distanceSq = column.X * column.X + column.Z * column.Z
				if distanceSq > farthestDistanceSq then
					farthestDistanceSq = distanceSq
					farthestSide = column
				end
			end
		end
		if farthestSide then
			startColumn = farthestSide
		end
	end
	local startRadiusScale = randomNodeRadiusScale(endpointRng)
	local usedNodes = {
		{
			X = startColumn.X,
			Z = startColumn.Z,
			Height = startColumn.SurfaceY,
			RadiusScale = startRadiusScale,
		},
	} :: { PathPoint }
	local baseAngle = endpointRng:NextNumber(0, math.pi * 2)
	local minEndpointAngleFromStart = math.rad(90)
	local minEndpointAngleBetween = math.rad(90)
	local acceptedEndpointAngles = {} :: { number }

	local function canAcceptEndpointAngle(angle: number): boolean
		if angularDistance(angle, startAngle) < minEndpointAngleFromStart then
			return false
		end
		for _, existingAngle in ipairs(acceptedEndpointAngles) do
			if angularDistance(angle, existingAngle) < minEndpointAngleBetween then
				return false
			end
		end
		return true
	end

	for endpointIndex = 1, endpointCount do
		local angleStep = (math.pi * 2) / endpointCount
		local jitter = endpointRng:NextNumber(-angleStep * 0.2, angleStep * 0.2)
		local endpointAngle = baseAngle + angleStep * (endpointIndex - 1) + jitter
		if not canAcceptEndpointAngle(endpointAngle) then
			continue
		end
		local endpointRadius = radius
			* endpointRng:NextNumber(TerrainTuning.PathEndpointRadiusMin, TerrainTuning.PathEndpointRadiusMax)
		local targetX = math.cos(endpointAngle) * endpointRadius
		local targetZ = math.sin(endpointAngle) * endpointRadius
		local endpoint = getNearestSolidColumnToTarget(columns, targetX, targetZ, radius * radius * 0.22, startColumn)
		local isSideEndpoint = endpoint and ((endpoint.X * endpoint.X + endpoint.Z * endpoint.Z) >= sideMinDistanceSq)
		if
			isSideEndpoint
			and endpoint
			and not hasNodeOverlap(
				usedNodes,
				endpoint.X,
				endpoint.Z,
				nodeMinSpacing,
				TerrainTuning.PathNodeRadiusScaleMax
			)
		then
			local resolvedEndpointAngle = math.atan2(endpoint.Z, endpoint.X)
			if not canAcceptEndpointAngle(resolvedEndpointAngle) then
				continue
			end
			table.insert(endpoints, endpoint)
			local route = generateWindingPathNodes(
				columns,
				startColumn,
				endpoint,
				usedNodes,
				startRadiusScale,
				seed + endpointIndex * 97
			)
			if #route >= 2 then
				table.insert(acceptedEndpointAngles, resolvedEndpointAngle)
				table.insert(allRoutes, route)
			end
		end
	end

	if #allRoutes < 2 then
		local fallbackCandidates = {} :: { TileColumn }
		for _, column in pairs(columns) do
			if column.Solid and not column.HasWater then
				local radialSq = column.X * column.X + column.Z * column.Z
				if radialSq >= sideMinDistanceSq then
					local angle = math.atan2(column.Z, column.X)
					if angularDistance(angle, startAngle) >= minEndpointAngleFromStart then
						table.insert(fallbackCandidates, column)
					end
				end
			end
		end
		table.sort(fallbackCandidates, function(a: TileColumn, b: TileColumn): boolean
			local adx = a.X - startColumn.X
			local adz = a.Z - startColumn.Z
			local bdx = b.X - startColumn.X
			local bdz = b.Z - startColumn.Z
			return (adx * adx + adz * adz) > (bdx * bdx + bdz * bdz)
		end)

		local fallbackSeed = seed + 713
		for _, candidate in ipairs(fallbackCandidates) do
			if #allRoutes >= 2 then
				break
			end
			if
				hasNodeOverlap(
					usedNodes,
					candidate.X,
					candidate.Z,
					nodeMinSpacing,
					TerrainTuning.PathNodeRadiusScaleMax
				)
			then
				continue
			end
			local candidateAngle = math.atan2(candidate.Z, candidate.X)
			if not canAcceptEndpointAngle(candidateAngle) then
				continue
			end
			local route =
				generateWindingPathNodes(columns, startColumn, candidate, usedNodes, startRadiusScale, fallbackSeed)
			fallbackSeed += 97
			if #route >= 2 then
				table.insert(acceptedEndpointAngles, candidateAngle)
				table.insert(endpoints, candidate)
				table.insert(allRoutes, route)
			end
		end
	end

	if #allRoutes < 2 then
		local fallbackSeed = seed + 1901
		for _, candidate in pairs(columns) do
			if #allRoutes >= 2 then
				break
			end
			if not candidate.Solid or candidate.HasWater then
				continue
			end
			if
				hasNodeOverlap(
					usedNodes,
					candidate.X,
					candidate.Z,
					nodeMinSpacing,
					TerrainTuning.PathNodeRadiusScaleMax
				)
			then
				continue
			end
			local candidateAngle = math.atan2(candidate.Z, candidate.X)
			if not canAcceptEndpointAngle(candidateAngle) then
				continue
			end
			local route =
				generateWindingPathNodes(columns, startColumn, candidate, usedNodes, startRadiusScale, fallbackSeed)
			fallbackSeed += 131
			if #route >= 2 then
				table.insert(acceptedEndpointAngles, candidateAngle)
				table.insert(endpoints, candidate)
				table.insert(allRoutes, route)
			end
		end
	end

	if #allRoutes > 0 and #allRoutes[1] > 0 then
		local startNode = allRoutes[1][1]
		local routeStartColumn = columns[makeColumnKey(startNode.X, startNode.Z)]
		if routeStartColumn and routeStartColumn.Solid then
			startColumn = routeStartColumn
		end
	end
	local pathHalfWidth = TerrainTuning.PathHalfWidth

	local function sampleRingAverageSurfaceY(
		centerX: number,
		centerZ: number,
		innerRadius: number,
		outerRadius: number
	): number?
		local tileRange = math.max(1, math.ceil(outerRadius + 1))
		local sumHeight = 0
		local count = 0
		for dx = -tileRange, tileRange do
			for dz = -tileRange, tileRange do
				local distance = math.sqrt(dx * dx + dz * dz)
				if distance >= innerRadius and distance <= outerRadius then
					local neighbor = columns[makeColumnKey(centerX + dx, centerZ + dz)]
					if neighbor and neighbor.Solid then
						sumHeight += neighbor.SurfaceY
						count += 1
					end
				end
			end
		end
		if count <= 0 then
			return nil
		end
		return sumHeight / count
	end

	local cityNodeCount = math.max(0, TerrainTuning.CityNodeCount)
	if cityNodeCount > 0 then
		local cityRng = Random.new(seed + 90301)
		local cityRadiusMin = math.clamp(TerrainTuning.CityRadiusMin, 0.05, 1)
		local cityRadiusMax = math.clamp(TerrainTuning.CityRadiusMax, cityRadiusMin, 1.2)
		local cityPlacementAttempts = math.max(1, TerrainTuning.CityPlacementAttempts)
		local cityNodeSpacing = math.max(
			nodeMinSpacing,
			math.max(2, TerrainTuning.PathNodeSpacing * math.max(0.5, TerrainTuning.CityNodeSpacingMultiplier))
		)
		local cityRadiusScaleMin = TerrainTuning.CityNodeRadiusScaleMin
		local cityRadiusScaleMax = TerrainTuning.CityNodeRadiusScaleMax
		if cityRadiusScaleMin > cityRadiusScaleMax then
			cityRadiusScaleMin, cityRadiusScaleMax = cityRadiusScaleMax, cityRadiusScaleMin
		end

		for _ = 1, cityNodeCount do
			local placedNode: PathPoint? = nil
			for _ = 1, cityPlacementAttempts do
				local angle = cityRng:NextNumber(0, math.pi * 2)
				local localRadius = radius * cityRng:NextNumber(cityRadiusMin, cityRadiusMax)
				local targetX = math.cos(angle) * localRadius
				local targetZ = math.sin(angle) * localRadius
				local candidate = getNearestSolidColumnToTarget(columns, targetX, targetZ, nil, nil)
				if candidate and candidate.Solid and not candidate.HasWater then
					local candidateRadiusScale = cityRng:NextNumber(cityRadiusScaleMin, cityRadiusScaleMax)
					if
						not hasNodeOverlap(usedNodes, candidate.X, candidate.Z, cityNodeSpacing, candidateRadiusScale)
					then
						local candidateRadius = math.max(pathHalfWidth, pathHalfWidth * candidateRadiusScale)
						local edgeInner = math.max(1, candidateRadius * TerrainTuning.CityFlattenEdgeInnerRatio)
						local edgeOuter =
							math.max(edgeInner + 0.5, candidateRadius * TerrainTuning.CityFlattenEdgeOuterRatio)
						local edgeAverage = sampleRingAverageSurfaceY(candidate.X, candidate.Z, edgeInner, edgeOuter)
						local edgeBlend = math.clamp(TerrainTuning.CityFlattenEdgeBlend, 0, 1)
						local flattenedHeight = candidate.SurfaceY
						if edgeAverage then
							flattenedHeight = snapHeight(candidate.SurfaceY * (1 - edgeBlend) + edgeAverage * edgeBlend)
						end
						placedNode = {
							X = candidate.X,
							Z = candidate.Z,
							Height = flattenedHeight,
							RadiusScale = candidateRadiusScale,
						}
						break
					end
				end
			end

			if placedNode then
				table.insert(usedNodes, placedNode)
				table.insert(allRoutes, { placedNode })
			end
		end
	end

	local basePathCells = {} :: { [string]: number }
	local function addBasePathCell(x: number, z: number, height: number)
		local key = makeColumnKey(x, z)
		if basePathCells[key] == nil then
			basePathCells[key] = height
		else
			basePathCells[key] = (basePathCells[key] + height) * 0.5
		end
	end

	local function rasterizeStraightSegment(a: PathPoint, b: PathPoint)
		local x0 = a.X
		local z0 = a.Z
		local x1 = b.X
		local z1 = b.Z
		local dx = math.abs(x1 - x0)
		local sx = if x0 < x1 then 1 else -1
		local dzAbs = math.abs(z1 - z0)
		local dz = -dzAbs
		local sz = if z0 < z1 then 1 else -1
		local err = dx + dz
		local stepCount = math.max(1, math.max(dx, dzAbs))
		local stepIndex = 0

		while true do
			local column = columns[makeColumnKey(x0, z0)]
			if column and column.Solid then
				local t = stepIndex / stepCount
				local sampleHeight = a.Height + (b.Height - a.Height) * t
				addBasePathCell(x0, z0, sampleHeight)
			end

			if x0 == x1 and z0 == z1 then
				break
			end

			local e2 = 2 * err
			if e2 >= dz then
				err += dz
				x0 += sx
			end
			if e2 <= dx then
				err += dx
				z0 += sz
			end
			stepIndex += 1
		end
	end

	local function circleTouchesTile(
		tileX: number,
		tileZ: number,
		centerX: number,
		centerZ: number,
		radius: number
	): boolean
		local dx = math.abs(tileX - centerX)
		local dz = math.abs(tileZ - centerZ)
		local nearestX = math.max(dx - 0.5, 0)
		local nearestZ = math.max(dz - 0.5, 0)
		return (nearestX * nearestX + nearestZ * nearestZ) <= (radius * radius + 1e-6)
	end

	local supportSearchRadius = math.max(2, TerrainTuning.SupportSearchRadius)
	local function resolveSupportReference(x: number, z: number): TileColumn?
		local existing = columns[makeColumnKey(x, z)]
		if existing and existing.Solid then
			return existing
		end

		return getSolidColumnNear(columns, x, z, supportSearchRadius)
	end

	local function ensureSupportedColumn(
		x: number,
		z: number,
		targetHeight: number,
		preferredBiome: string?,
		minThickness: number
	): TileColumn?
		local key = makeColumnKey(x, z)
		local column = columns[key]
		if not column then
			return nil
		end
		local wasSolid = column.Solid

		local reference = resolveSupportReference(x, z)
		local biome = preferredBiome
		if biome == nil then
			biome = if reference then reference.Biome else config.Biome
		end
		local materials = getBiomeMaterials(biome)

		if not wasSolid then
			column.Solid = true
			column.Biome = biome
			column.SurfaceMaterial = materials.Surface
			column.FillMaterial = materials.Deep
			column.PathMaterial = nil
		end

		if column.Biome == "" then
			column.Biome = biome
		end

		column.HasWater = false
		column.IsPath = false
		column.PathMaterial = nil
		column.StructureTag = nil

		local surfaceY = snapHeight(targetHeight)
		if reference then
			local referenceSurface = reference.SurfaceY
			local maxRiseFromReference = math.max(0, TerrainTuning.SupportMaxRiseFromReference)
			if surfaceY > referenceSurface + maxRiseFromReference then
				surfaceY = referenceSurface + maxRiseFromReference
			end
		end
		if wasSolid then
			-- Never carve existing terrain downward in support passes.
			surfaceY = column.SurfaceY
		end
		column.SurfaceY = surfaceY

		local supportThickness = math.max(minThickness, TerrainTuning.ThicknessMin)
		local desiredBottom = surfaceY - supportThickness
		if reference then
			desiredBottom = math.min(desiredBottom, reference.BottomY + 2)
		end
		column.BottomY = math.min(column.BottomY, desiredBottom)

		return column
	end

	local function paintSupportDisk(
		centerX: number,
		centerZ: number,
		targetHeight: number,
		radiusTiles: number,
		preferredBiome: string?,
		minThickness: number
	)
		local tileRange = math.max(1, math.ceil(radiusTiles + 0.85))
		local edgeDrop = TerrainTuning.SupportBridgeEdgeDrop
		for dx = -tileRange, tileRange do
			for dz = -tileRange, tileRange do
				local tileX = centerX + dx
				local tileZ = centerZ + dz
				if circleTouchesTile(tileX, tileZ, centerX, centerZ, radiusTiles) then
					local localDistance = math.sqrt(dx * dx + dz * dz)
					local edgeAlpha = smoothstep(0, radiusTiles + 0.25, localDistance)
					local sampledHeight = targetHeight - edgeAlpha * edgeDrop
					ensureSupportedColumn(tileX, tileZ, sampledHeight, preferredBiome, minThickness)
				end
			end
		end
	end

	local function createSupportBridgeBetween(a: PathPoint, b: PathPoint)
		local x0 = a.X
		local z0 = a.Z
		local x1 = b.X
		local z1 = b.Z
		local dx = math.abs(x1 - x0)
		local sx = if x0 < x1 then 1 else -1
		local dzAbs = math.abs(z1 - z0)
		local dz = -dzAbs
		local sz = if z0 < z1 then 1 else -1
		local err = dx + dz
		local stepCount = math.max(1, math.max(dx, dzAbs))
		local stepIndex = 0
		local bridgeHalfWidth = math.max(pathHalfWidth + 0.25, TerrainTuning.SupportBridgeHalfWidth)
		local bridgeThickness = math.max(TerrainTuning.SupportBridgeThickness, TerrainTuning.SupportIslandThickness)
		local startColumn = resolveSupportReference(a.X, a.Z)
		local endColumn = resolveSupportReference(b.X, b.Z)
		local preferredBiome = if startColumn
			then startColumn.Biome
			else if endColumn then endColumn.Biome else config.Biome
		if not isMountainBiome(preferredBiome) then
			return
		end

		while true do
			local t = stepIndex / stepCount
			local sampleHeight = a.Height + (b.Height - a.Height) * t
			paintSupportDisk(x0, z0, sampleHeight, bridgeHalfWidth, preferredBiome, bridgeThickness)

			if x0 == x1 and z0 == z1 then
				break
			end

			local e2 = 2 * err
			if e2 >= dz then
				err += dz
				x0 += sx
			end
			if e2 <= dx then
				err += dx
				z0 += sz
			end
			stepIndex += 1
		end
	end

	for _, route in ipairs(allRoutes) do
		for _, node in ipairs(route) do
			local nodeBaseRadius = math.max(pathHalfWidth, pathHalfWidth * node.RadiusScale)
			local supportRadius =
				math.max(TerrainTuning.SupportIslandMinRadius, nodeBaseRadius + TerrainTuning.SupportIslandExtraRadius)
			local referenceColumn = resolveSupportReference(node.X, node.Z)
			local preferredBiome = if referenceColumn then referenceColumn.Biome else config.Biome
			if not isMountainBiome(preferredBiome) then
				continue
			end
			local targetHeight = node.Height
			if referenceColumn then
				targetHeight = math.min(targetHeight, referenceColumn.SurfaceY)
			end
			paintSupportDisk(
				node.X,
				node.Z,
				targetHeight,
				supportRadius,
				preferredBiome,
				TerrainTuning.SupportIslandThickness
			)
		end
	end

	for _, route in ipairs(allRoutes) do
		for pointIndex = 1, #route - 1 do
			createSupportBridgeBetween(route[pointIndex], route[pointIndex + 1])
		end
	end

	for _, route in ipairs(allRoutes) do
		for pointIndex = 1, #route - 1 do
			rasterizeStraightSegment(route[pointIndex], route[pointIndex + 1])
		end
	end

	local pathCells = {} :: { [string]: number }
	local widthRadius = math.max(1, math.floor(pathHalfWidth + 0.5))

	for key, baseHeight in pairs(basePathCells) do
		local split = string.split(key, ":")
		local bx = tonumber(split[1])
		local bz = tonumber(split[2])
		if bx and bz then
			for dx = -widthRadius, widthRadius do
				for dz = -widthRadius, widthRadius do
					local localDist = math.sqrt(dx * dx + dz * dz)
					if localDist <= pathHalfWidth + 0.15 then
						local candidate = columns[makeColumnKey(bx + dx, bz + dz)]
						if candidate and candidate.Solid then
							local candidateKey = makeColumnKey(candidate.X, candidate.Z)
							if pathCells[candidateKey] == nil then
								pathCells[candidateKey] = baseHeight
							else
								pathCells[candidateKey] = (pathCells[candidateKey] + baseHeight) * 0.5
							end
						end
					end
				end
			end
		end
	end

	for _, route in ipairs(allRoutes) do
		for _, node in ipairs(route) do
			local nodeRadius = math.max(pathHalfWidth, pathHalfWidth * node.RadiusScale)
			local tileRange = math.max(1, math.ceil(nodeRadius + 0.75))
			local nodeHeightBlendStrength = math.clamp(TerrainTuning.PathNodeHeightBlendStrength, 0, 1)
			for dx = -tileRange, tileRange do
				for dz = -tileRange, tileRange do
					local tileX = node.X + dx
					local tileZ = node.Z + dz
					if circleTouchesTile(tileX, tileZ, node.X, node.Z, nodeRadius) then
						local candidate = columns[makeColumnKey(tileX, tileZ)]
						if candidate and candidate.Solid then
							local localDistance = math.sqrt(dx * dx + dz * dz)
							local blendAlpha = (1 - smoothstep(nodeRadius * 0.2, nodeRadius, localDistance))
								* nodeHeightBlendStrength
							local candidateKey = makeColumnKey(candidate.X, candidate.Z)
							if pathCells[candidateKey] == nil then
								pathCells[candidateKey] = node.Height
							else
								pathCells[candidateKey] = pathCells[candidateKey] * (1 - blendAlpha)
									+ node.Height * blendAlpha
							end
						end
					end
				end
			end
		end
	end

	local bridgePasses = math.max(0, TerrainTuning.PathConnectivityBridgePasses)
	for _ = 1, bridgePasses do
		local additions = {} :: { [string]: number }
		for key, sourceHeight in pairs(pathCells) do
			local split = string.split(key, ":")
			local x = tonumber(split[1])
			local z = tonumber(split[2])
			if x and z then
				local function tryBridge(midX: number, midZ: number, endX: number, endZ: number)
					local endKey = makeColumnKey(endX, endZ)
					local endHeight = pathCells[endKey]
					if endHeight == nil then
						return
					end
					local midKey = makeColumnKey(midX, midZ)
					if pathCells[midKey] ~= nil or additions[midKey] ~= nil then
						return
					end
					local candidate = columns[midKey]
					if not candidate or not candidate.Solid then
						return
					end
					additions[midKey] = (sourceHeight + endHeight) * 0.5
				end

				tryBridge(x + 1, z, x + 2, z)
				tryBridge(x - 1, z, x - 2, z)
				tryBridge(x, z + 1, x, z + 2)
				tryBridge(x, z - 1, x, z - 2)
			end
		end

		if next(additions) == nil then
			break
		end
		for key, height in pairs(additions) do
			pathCells[key] = height
		end
	end

	local flattenNoiseOffsetX = (seed % 1297) * 0.09
	local flattenNoiseOffsetZ = (seed % 1499) * 0.08
	local pathTargetHeights = {} :: { [string]: number }
	local originalPathSurfaceByKey = {} :: { [string]: number }
	local nodeCoreInfluenceByKey = {} :: { [string]: number }
	local nodeFlattenInfluenceByKey = {} :: { [string]: { SumHeight: number, SumWeight: number } }
	local nodeFlattenProtectedKeys = {} :: { [string]: boolean }
	local nonMountainPreserveAlpha = math.clamp(TerrainTuning.PathNonMountainPreserveAlpha, 0, 1)
	local nonMountainMaxCutDepth = math.max(0, TerrainTuning.PathNonMountainMaxCutDepth)
	local nodeFlattenMaxCutDepth = math.max(nonMountainMaxCutDepth, TerrainTuning.PathNodeFlattenMaxCutDepth)
	local nodeFlattenStrength = math.clamp(TerrainTuning.PathNodeFlattenStrength, 0, 1)
	local nodeFlattenRadiusMultiplier = math.max(1, TerrainTuning.PathNodeFlattenRadiusMultiplier)
	local nodeFlattenCore = math.clamp(TerrainTuning.PathNodeFlattenCore, 0, 0.92)
	local nodeFlattenMinimumRadiusTiles = math.max(1, TerrainTuning.PathNodeFlattenMinimumRadiusTiles)
	local nodeFlattenHardRadiusRatio = math.clamp(TerrainTuning.PathNodeFlattenHardRadiusRatio, 0.05, 0.98)
	if nodeFlattenHardRadiusRatio <= nodeFlattenCore then
		nodeFlattenHardRadiusRatio = math.min(0.98, nodeFlattenCore + 0.05)
	end
	local nodeFlattenEdgeFloorInfluence = math.clamp(TerrainTuning.PathNodeFlattenEdgeFloorInfluence, 0, 0.95)

	for _, route in ipairs(allRoutes) do
		for _, node in ipairs(route) do
			local pathRadiusTiles = getPathNodeBaseRadiusTiles(node.RadiusScale)
			local flattenRadiusTiles = math.max(
				pathRadiusTiles,
				math.max(pathRadiusTiles * nodeFlattenRadiusMultiplier, nodeFlattenMinimumRadiusTiles)
			)
			node.PathRadiusTiles = pathRadiusTiles
			node.FlattenRadiusTiles = flattenRadiusTiles
		end
	end

	if nodeFlattenStrength > 0 then
		for _, route in ipairs(allRoutes) do
			for _, node in ipairs(route) do
				local flattenRadiusTiles = if node.FlattenRadiusTiles then node.FlattenRadiusTiles else pathHalfWidth
				local tileRange = math.max(1, math.ceil(flattenRadiusTiles + 0.75))
				for dx = -tileRange, tileRange do
					for dz = -tileRange, tileRange do
						local tileX = node.X + dx
						local tileZ = node.Z + dz
						if circleTouchesTile(tileX, tileZ, node.X, node.Z, flattenRadiusTiles) then
							local candidate = columns[makeColumnKey(tileX, tileZ)]
							if candidate and candidate.Solid then
								local localDistance = math.sqrt(dx * dx + dz * dz)
								local normalizedDistance = if flattenRadiusTiles > 0
									then localDistance / flattenRadiusTiles
									else 0
								local radialInfluence = 1
									- smoothstep(nodeFlattenHardRadiusRatio, 1, normalizedDistance)
								local influenceAlpha = nodeFlattenEdgeFloorInfluence
									+ radialInfluence * (1 - nodeFlattenEdgeFloorInfluence)
								local coreInfluence = 1 - smoothstep(nodeFlattenCore, 1, normalizedDistance)
								if influenceAlpha > 0 then
									local candidateKey = makeColumnKey(candidate.X, candidate.Z)
									local existingCoreInfluence = nodeCoreInfluenceByKey[candidateKey]
									if existingCoreInfluence == nil or coreInfluence > existingCoreInfluence then
										nodeCoreInfluenceByKey[candidateKey] = coreInfluence
									end
									if coreInfluence >= 0.65 then
										nodeFlattenProtectedKeys[candidateKey] = true
									end
									local influence = nodeFlattenInfluenceByKey[candidateKey]
									if not influence then
										influence = { SumHeight = 0, SumWeight = 0 }
										nodeFlattenInfluenceByKey[candidateKey] = influence
									end
									influence.SumHeight += node.Height * influenceAlpha
									influence.SumWeight += influenceAlpha
								end
							end
						end
					end
				end
			end
		end
	end

	local function getPathMinimumHeight(key: string, column: TileColumn): number
		local minPathY = column.BottomY + 2
		local originalSurfaceY = originalPathSurfaceByKey[key]
		if originalSurfaceY ~= nil then
			local maxCutDepth = nonMountainMaxCutDepth
			local coreInfluence = nodeCoreInfluenceByKey[key]
			if coreInfluence and coreInfluence > 0 then
				maxCutDepth = nonMountainMaxCutDepth + (nodeFlattenMaxCutDepth - nonMountainMaxCutDepth) * coreInfluence
			end
			local cutFloorY = snapHeight(originalSurfaceY - maxCutDepth)
			if cutFloorY > minPathY then
				minPathY = cutFloorY
			end
		end
		return minPathY
	end

	for key, baseHeight in pairs(pathCells) do
		local column = columns[key]
		if column and column.Solid then
			local originalSurfaceY = column.SurfaceY
			originalPathSurfaceByKey[key] = originalSurfaceY
			local flattenNoise = math.noise(
				(column.X + flattenNoiseOffsetX) * 0.08,
				(column.Z + flattenNoiseOffsetZ) * 0.08,
				seed * 0.0027
			) * TerrainTuning.PathFlattenNoiseAmplitude
			local pathTargetY = snapHeight(baseHeight + flattenNoise)
			if pathTargetY > originalSurfaceY then
				pathTargetY = originalSurfaceY
			end
			local minPathY = getPathMinimumHeight(key, column)
			if pathTargetY < minPathY then
				pathTargetY = minPathY
			end

			local edgeBlend = math.clamp(TerrainTuning.PathEdgeBlend, 0, 1) * 0.55
			local edgeSampleRadius = math.max(1, TerrainTuning.PathEdgeSampleRadius)
			if edgeBlend > 0 then
				local edgeSum = 0
				local edgeCount = 0
				for dx = -edgeSampleRadius, edgeSampleRadius do
					for dz = -edgeSampleRadius, edgeSampleRadius do
						if dx == 0 and dz == 0 then
							continue
						end
						local neighborKey = makeColumnKey(column.X + dx, column.Z + dz)
						if pathCells[neighborKey] == nil then
							local neighbor = columns[neighborKey]
							if neighbor and neighbor.Solid then
								edgeSum += neighbor.SurfaceY
								edgeCount += 1
							end
						end
					end
				end
				if edgeCount > 0 then
					local edgeAverage = edgeSum / edgeCount
					pathTargetY = snapHeight(pathTargetY * (1 - edgeBlend) + edgeAverage * edgeBlend)
					if pathTargetY > originalSurfaceY then
						pathTargetY = originalSurfaceY
					end
					if pathTargetY < minPathY then
						pathTargetY = minPathY
					end
				end
			end

			-- Keep paths near local terrain while still leveling path micro-variation.
			pathTargetY =
				snapHeight(pathTargetY * (1 - nonMountainPreserveAlpha) + originalSurfaceY * nonMountainPreserveAlpha)
			if pathTargetY < minPathY then
				pathTargetY = minPathY
			end
			pathTargetHeights[key] = pathTargetY
		end
	end

	if nodeFlattenStrength > 0 then
		for key, influence in pairs(nodeFlattenInfluenceByKey) do
			local column = columns[key]
			if column and column.Solid and influence.SumWeight > 0 then
				if originalPathSurfaceByKey[key] == nil then
					originalPathSurfaceByKey[key] = column.SurfaceY
				end
				local desiredHeight = influence.SumHeight / influence.SumWeight
				local currentTargetY = pathTargetHeights[key]
				if currentTargetY == nil then
					currentTargetY = column.SurfaceY
				end
				local flattenedY =
					snapHeight(currentTargetY * (1 - nodeFlattenStrength) + desiredHeight * nodeFlattenStrength)
				if flattenedY > column.SurfaceY then
					flattenedY = column.SurfaceY
				end
				local minPathY = getPathMinimumHeight(key, column)
				if flattenedY < minPathY then
					flattenedY = minPathY
				end
				pathTargetHeights[key] = flattenedY
				pathCells[key] = flattenedY
			end
		end
	end

	local mountainSmoothingPasses = math.max(0, TerrainTuning.MountainPathSmoothingPasses)
	for _ = 1, mountainSmoothingPasses do
		local nextHeights = {} :: { [string]: number }
		for key, currentTargetY in pairs(pathTargetHeights) do
			local column = columns[key]
			if column and column.Solid and isMountainBiome(column.Biome) then
				local sum = currentTargetY * 2
				local weight = 2
				local north = pathTargetHeights[makeColumnKey(column.X, column.Z - 1)]
				if north then
					sum += north
					weight += 1
				end
				local south = pathTargetHeights[makeColumnKey(column.X, column.Z + 1)]
				if south then
					sum += south
					weight += 1
				end
				local west = pathTargetHeights[makeColumnKey(column.X - 1, column.Z)]
				if west then
					sum += west
					weight += 1
				end
				local east = pathTargetHeights[makeColumnKey(column.X + 1, column.Z)]
				if east then
					sum += east
					weight += 1
				end
				local smoothed = snapHeight(sum / weight)
				if smoothed > column.SurfaceY then
					smoothed = column.SurfaceY
				end
				local minPathY = getPathMinimumHeight(key, column)
				if smoothed < minPathY then
					smoothed = minPathY
				end
				nextHeights[key] = smoothed
			else
				nextHeights[key] = currentTargetY
			end
		end
		pathTargetHeights = nextHeights
	end

	local continuityPasses = math.max(1, TerrainTuning.PathContinuityPasses)
	local continuityAlpha = math.clamp(TerrainTuning.PathContinuityBlendAlpha, 0, 1)
	local maxNeighborStep = math.max(TerrainTuning.HeightSnapStep, TerrainTuning.PathMaxNeighborStep)
	for _ = 1, continuityPasses do
		local nextHeights = {} :: { [string]: number }
		for key, currentTargetY in pairs(pathTargetHeights) do
			local column = columns[key]
			if not column or not column.Solid then
				continue
			end

			local hasNeighbor = false
			local sum = currentTargetY
			local weight = 1
			local minAllowed = -math.huge
			local maxAllowed = math.huge

			local neighborNorth = pathTargetHeights[makeColumnKey(column.X, column.Z - 1)]
			if neighborNorth then
				hasNeighbor = true
				sum += neighborNorth
				weight += 1
				minAllowed = math.max(minAllowed, neighborNorth - maxNeighborStep)
				maxAllowed = math.min(maxAllowed, neighborNorth + maxNeighborStep)
			end

			local neighborSouth = pathTargetHeights[makeColumnKey(column.X, column.Z + 1)]
			if neighborSouth then
				hasNeighbor = true
				sum += neighborSouth
				weight += 1
				minAllowed = math.max(minAllowed, neighborSouth - maxNeighborStep)
				maxAllowed = math.min(maxAllowed, neighborSouth + maxNeighborStep)
			end

			local neighborWest = pathTargetHeights[makeColumnKey(column.X - 1, column.Z)]
			if neighborWest then
				hasNeighbor = true
				sum += neighborWest
				weight += 1
				minAllowed = math.max(minAllowed, neighborWest - maxNeighborStep)
				maxAllowed = math.min(maxAllowed, neighborWest + maxNeighborStep)
			end

			local neighborEast = pathTargetHeights[makeColumnKey(column.X + 1, column.Z)]
			if neighborEast then
				hasNeighbor = true
				sum += neighborEast
				weight += 1
				minAllowed = math.max(minAllowed, neighborEast - maxNeighborStep)
				maxAllowed = math.min(maxAllowed, neighborEast + maxNeighborStep)
			end

			local nextY = currentTargetY
			if hasNeighbor then
				local average = sum / weight
				nextY = snapHeight(currentTargetY * (1 - continuityAlpha) + average * continuityAlpha)
				if minAllowed <= maxAllowed then
					nextY = math.clamp(nextY, minAllowed, maxAllowed)
				end
			end
			if nextY > column.SurfaceY then
				nextY = column.SurfaceY
			end
			local minPathY = getPathMinimumHeight(key, column)
			if nextY < minPathY then
				nextY = minPathY
			end
			nextHeights[key] = nextY
		end

		pathTargetHeights = nextHeights
	end

	if nodeFlattenStrength > 0 then
		for key, influence in pairs(nodeFlattenInfluenceByKey) do
			local column = columns[key]
			local currentTargetY = pathTargetHeights[key]
			if column and column.Solid and currentTargetY and influence.SumWeight > 0 then
				local desiredHeight = influence.SumHeight / influence.SumWeight
				local flattenedY =
					snapHeight(currentTargetY * (1 - nodeFlattenStrength) + desiredHeight * nodeFlattenStrength)
				if flattenedY > column.SurfaceY then
					flattenedY = column.SurfaceY
				end
				local minPathY = getPathMinimumHeight(key, column)
				if flattenedY < minPathY then
					flattenedY = minPathY
				end
				pathTargetHeights[key] = flattenedY
			end
		end

		local nodeSmoothingPasses = math.max(0, TerrainTuning.PathNodeFlattenSmoothingPasses)
		for _ = 1, nodeSmoothingPasses do
			local nextHeights = {} :: { [string]: number }
			for key, currentTargetY in pairs(pathTargetHeights) do
				if nodeFlattenInfluenceByKey[key] == nil then
					nextHeights[key] = currentTargetY
					continue
				end

				local column = columns[key]
				if not column or not column.Solid then
					nextHeights[key] = currentTargetY
					continue
				end

				local sum = currentTargetY * 2
				local weight = 2
				local north = pathTargetHeights[makeColumnKey(column.X, column.Z - 1)]
				if north then
					sum += north
					weight += 1
				end
				local south = pathTargetHeights[makeColumnKey(column.X, column.Z + 1)]
				if south then
					sum += south
					weight += 1
				end
				local west = pathTargetHeights[makeColumnKey(column.X - 1, column.Z)]
				if west then
					sum += west
					weight += 1
				end
				local east = pathTargetHeights[makeColumnKey(column.X + 1, column.Z)]
				if east then
					sum += east
					weight += 1
				end

				local smoothed = snapHeight(sum / weight)
				local smoothingBlend = math.min(0.75, nodeFlattenStrength * 0.55)
				local nextY = snapHeight(currentTargetY * (1 - smoothingBlend) + smoothed * smoothingBlend)
				if nextY > column.SurfaceY then
					nextY = column.SurfaceY
				end
				local minPathY = getPathMinimumHeight(key, column)
				if nextY < minPathY then
					nextY = minPathY
				end
				nextHeights[key] = nextY
			end
			pathTargetHeights = nextHeights
		end
	end

	local nonMountainSmoothingPasses = math.max(0, math.floor(TerrainTuning.PathNonMountainSmoothingPasses + 0.5))
	local nonMountainSmoothingBlend = math.clamp(TerrainTuning.PathNonMountainSmoothingBlend, 0, 1)
	for _ = 1, nonMountainSmoothingPasses do
		local nextHeights = {} :: { [string]: number }
		for key, currentTargetY in pairs(pathTargetHeights) do
			local column = columns[key]
			if not column or not column.Solid then
				nextHeights[key] = currentTargetY
				continue
			end
			if nodeFlattenProtectedKeys[key] then
				nextHeights[key] = currentTargetY
				continue
			end

			local north = pathTargetHeights[makeColumnKey(column.X, column.Z - 1)]
			local south = pathTargetHeights[makeColumnKey(column.X, column.Z + 1)]
			local west = pathTargetHeights[makeColumnKey(column.X - 1, column.Z)]
			local east = pathTargetHeights[makeColumnKey(column.X + 1, column.Z)]

			local sum = currentTargetY * 2
			local weight = 2
			local minAllowed = -math.huge
			local maxAllowed = math.huge
			local hasNeighbor = false
			local function includeNeighbor(neighborY: number?)
				if neighborY ~= nil then
					hasNeighbor = true
					sum += neighborY
					weight += 1
					minAllowed = math.max(minAllowed, neighborY - 1)
					maxAllowed = math.min(maxAllowed, neighborY + 1)
				end
			end
			includeNeighbor(north)
			includeNeighbor(south)
			includeNeighbor(west)
			includeNeighbor(east)

			local nextY = currentTargetY
			if hasNeighbor then
				local averagedY = sum / weight
				nextY =
					snapHeight(currentTargetY * (1 - nonMountainSmoothingBlend) + averagedY * nonMountainSmoothingBlend)
				if minAllowed <= maxAllowed then
					nextY = math.clamp(nextY, minAllowed, maxAllowed)
				end
			end

			if nextY > column.SurfaceY then
				nextY = column.SurfaceY
			end
			local minPathY = getPathMinimumHeight(key, column)
			if nextY < minPathY then
				nextY = minPathY
			end
			nextHeights[key] = nextY
		end
		pathTargetHeights = nextHeights
	end

	local aggressiveFlattenPasses = math.max(0, math.floor(TerrainTuning.PathAggressiveFlattenPasses + 0.5))
	local aggressiveFlattenBlend = math.clamp(TerrainTuning.PathAggressiveFlattenBlend, 0, 1)
	local maxPathRange = math.max(0, TerrainTuning.PathMaxHeightRange)
	if aggressiveFlattenPasses > 0 and maxPathRange > 0 and next(pathTargetHeights) ~= nil then
		local componentReferenceByKey = {} :: { [string]: number }
		local visited = {} :: { [string]: boolean }
		local neighborOffsets = {
			{ DX = 1, DZ = 0 },
			{ DX = -1, DZ = 0 },
			{ DX = 0, DZ = 1 },
			{ DX = 0, DZ = -1 },
		}

		local function assignComponentReference(startKey: string)
			local queue = { startKey }
			local headIndex = 1
			visited[startKey] = true
			local componentKeys = {} :: { string }
			local heights = {} :: { number }

			while headIndex <= #queue do
				local key = queue[headIndex]
				headIndex += 1
				table.insert(componentKeys, key)
				local currentHeight = pathTargetHeights[key]
				if currentHeight ~= nil then
					table.insert(heights, currentHeight)
				end

				local split = string.split(key, ":")
				local x = tonumber(split[1])
				local z = tonumber(split[2])
				if x and z then
					for _, offset in ipairs(neighborOffsets) do
						local neighborKey = makeColumnKey(x + offset.DX, z + offset.DZ)
						if pathTargetHeights[neighborKey] ~= nil and visited[neighborKey] ~= true then
							visited[neighborKey] = true
							table.insert(queue, neighborKey)
						end
					end
				end
			end

			if #heights <= 0 then
				return
			end

			table.sort(heights)
			local medianIndex = math.clamp(math.floor((#heights + 1) * 0.5 + 0.5), 1, #heights)
			local referenceHeight = heights[medianIndex]
			for _, componentKey in ipairs(componentKeys) do
				componentReferenceByKey[componentKey] = referenceHeight
			end
		end

		for key in pairs(pathTargetHeights) do
			if visited[key] ~= true then
				assignComponentReference(key)
			end
		end

		local maxDeviation = maxPathRange * 0.5
		for _ = 1, aggressiveFlattenPasses do
			local nextHeights = {} :: { [string]: number }
			for key, currentTargetY in pairs(pathTargetHeights) do
				local column = columns[key]
				if not column or not column.Solid then
					continue
				end

				local split = string.split(key, ":")
				local x = tonumber(split[1])
				local z = tonumber(split[2])
				local sum = currentTargetY * 2
				local weight = 2
				if x and z then
					local north = pathTargetHeights[makeColumnKey(x, z - 1)]
					if north ~= nil then
						sum += north
						weight += 1
					end
					local south = pathTargetHeights[makeColumnKey(x, z + 1)]
					if south ~= nil then
						sum += south
						weight += 1
					end
					local west = pathTargetHeights[makeColumnKey(x - 1, z)]
					if west ~= nil then
						sum += west
						weight += 1
					end
					local east = pathTargetHeights[makeColumnKey(x + 1, z)]
					if east ~= nil then
						sum += east
						weight += 1
					end
				end

				local localAverage = sum / weight
				local blendedY = currentTargetY * (1 - aggressiveFlattenBlend) + localAverage * aggressiveFlattenBlend
				local referenceHeight = componentReferenceByKey[key] or blendedY
				local boundedY = math.clamp(blendedY, referenceHeight - maxDeviation, referenceHeight + maxDeviation)
				local nextY = snapHeight(boundedY)
				if nextY > column.SurfaceY then
					nextY = column.SurfaceY
				end
				local minPathY = getPathMinimumHeight(key, column)
				if nextY < minPathY then
					nextY = minPathY
				end
				nextHeights[key] = nextY
			end
			pathTargetHeights = nextHeights
		end
	end

	for key, pathTargetY in pairs(pathTargetHeights) do
		local column = columns[key]
		if column and column.Solid then
			column.SurfaceY = pathTargetY
			column.HasWater = false
			column.IsPath = true
			column.StructureTag = nil
			if isMountainBiome(column.Biome) then
				column.PathMaterial = Enum.Material.Rock
			elseif isPlainsBiome(column.Biome) then
				column.PathMaterial = Enum.Material.Sand
			elseif isForestBiome(column.Biome) then
				column.PathMaterial = Enum.Material.Ground
			end
			if column.PathMaterial then
				column.SurfaceMaterial = column.PathMaterial
			end
		end
	end

	local shoulderWidth = math.max(pathHalfWidth + 0.5, TerrainTuning.PathShoulderWidth)
	local shoulderRadius = math.max(1, math.floor(shoulderWidth + 0.5))
	for key, baseHeight in pairs(pathCells) do
		local split = string.split(key, ":")
		local bx = tonumber(split[1])
		local bz = tonumber(split[2])
		if bx and bz then
			local pathColumn = columns[key]
			local pathSurfaceY = if pathColumn and pathColumn.Solid then pathColumn.SurfaceY else baseHeight
			for dx = -shoulderRadius, shoulderRadius do
				for dz = -shoulderRadius, shoulderRadius do
					local localDist = math.sqrt(dx * dx + dz * dz)
					if localDist > pathHalfWidth and localDist <= shoulderWidth then
						local neighbor = columns[makeColumnKey(bx + dx, bz + dz)]
						if neighbor and neighbor.Solid then
							if isMountainBiome(neighbor.Biome) and not neighbor.IsPath then
								local shoulderAlpha = 1 - smoothstep(pathHalfWidth, shoulderWidth, localDist)
								local cliffRise = shoulderAlpha * TerrainTuning.PathMountainCliffRise
								local minCliffHeight = math.floor(pathSurfaceY + 2 + cliffRise)
								if neighbor.SurfaceY < minCliffHeight then
									local heightDelta = minCliffHeight - neighbor.SurfaceY
									neighbor.SurfaceY = neighbor.SurfaceY
										+ math.max(1, math.floor(heightDelta * 0.55 + 0.5))
								end
							end
							if isForestBiome(neighbor.Biome) and localDist <= TerrainTuning.PathForestClearingWidth then
								neighbor.StructureTag = nil
							end
						end
					end
				end
			end
		end
	end

	if RuntimeNodeStructuresEnabled then
		local nodeStructureRng = Random.new(seed + 47993)
		local assignedNodeColumns = {} :: { [string]: boolean }
		local lockedStructureColumns = {} :: { [string]: boolean }
		local assemblyPlacementEnabled = RuntimeNodeAssemblyPlacement.Enabled == true
		local assemblyLockInEnabled = RuntimeNodeAssemblyPlacement.LockInEnabled == true
		local assemblySearchRadius =
			math.max(0, math.floor((RuntimeNodeAssemblyPlacement.SearchRadiusTiles or 0) + 0.5))
		local assemblySearchRadiusSq = assemblySearchRadius * assemblySearchRadius
		local assemblyAvoidPathCells = RuntimeNodeAssemblyPlacement.AvoidPathCells == true
		local assemblyAvoidWaterCells = RuntimeNodeAssemblyPlacement.AvoidWaterCells == true
		local assemblyMaxHeightDelta = 8
		local tileSize = math.max(1, config.TileSize)
		local habitationFootprintPaddingTiles = 2
		local environmentFootprintPaddingTiles = 1
		local defaultFootprintPaddingTiles = 1

		local function canReplaceColumnStructure(column: TileColumn): boolean
			if column.StructureTag == nil then
				return true
			end
			local existingDefinition = PrefabRegistry.GetById(column.StructureTag)
			return existingDefinition ~= nil and existingDefinition.Category == "Nature"
		end

		local function isStructurePlacementColumnValid(column: TileColumn?): boolean
			if not column or not column.Solid then
				return false
			end
			if assemblyAvoidWaterCells and column.HasWater then
				return false
			end
			if assemblyAvoidPathCells and column.IsPath then
				return false
			end
			if not canReplaceColumnStructure(column) then
				return false
			end
			return true
		end

		local function getPrefabPlacementFootprint(prefabId: string): (number?, number?, number?)
			local definition = PrefabRegistry.GetById(prefabId)
			if not definition or definition.Category ~= "Structure" then
				return nil
			end

			local structureScale = getRuntimeStructureScale(definition)
			local halfX = math.max(1, math.ceil((definition.FootprintStuds.X * structureScale * 0.5) / tileSize))
			local halfZ = math.max(1, math.ceil((definition.FootprintStuds.Y * structureScale * 0.5) / tileSize))
			local lowerName = string.lower(definition.Name)
			local padding = defaultFootprintPaddingTiles
			if isHabitationStructureName(lowerName) then
				padding = habitationFootprintPaddingTiles
			elseif isEnvironmentStructureName(lowerName) then
				padding = environmentFootprintPaddingTiles
			end
			return halfX, halfZ, padding
		end

		local function canPlacePrefabFootprintAt(
			centerX: number,
			centerZ: number,
			prefabId: string,
			anchorHeight: number,
			reservedKeys: { [string]: boolean }
		): boolean
			local halfXOrNil, halfZOrNil, paddingOrNil = getPrefabPlacementFootprint(prefabId)
			if halfXOrNil == nil or halfZOrNil == nil or paddingOrNil == nil then
				return false
			end
			local halfX = halfXOrNil
			local halfZ = halfZOrNil
			local padding = paddingOrNil

			local extentX = halfX + padding
			local extentZ = halfZ + padding
			for dx = -extentX, extentX do
				for dz = -extentZ, extentZ do
					local footprintKey = makeColumnKey(centerX + dx, centerZ + dz)
					if reservedKeys[footprintKey] or assignedNodeColumns[footprintKey] then
						return false
					end
					if assemblyLockInEnabled and lockedStructureColumns[footprintKey] then
						return false
					end

					local footprintColumn = columns[footprintKey]
					if not isStructurePlacementColumnValid(footprintColumn) then
						return false
					end
					if math.abs(footprintColumn.SurfaceY - anchorHeight) > assemblyMaxHeightDelta then
						return false
					end
				end
			end

			return true
		end

		local function reservePrefabFootprint(
			reservedKeys: { [string]: boolean },
			centerX: number,
			centerZ: number,
			prefabId: string
		): { string }
			local halfXOrNil, halfZOrNil, paddingOrNil = getPrefabPlacementFootprint(prefabId)
			local footprintKeys = {} :: { string }
			if halfXOrNil == nil or halfZOrNil == nil or paddingOrNil == nil then
				local centerKey = makeColumnKey(centerX, centerZ)
				reservedKeys[centerKey] = true
				table.insert(footprintKeys, centerKey)
				return footprintKeys
			end
			local halfX = halfXOrNil
			local halfZ = halfZOrNil
			local padding = paddingOrNil

			local extentX = halfX + padding
			local extentZ = halfZ + padding
			for dx = -extentX, extentX do
				for dz = -extentZ, extentZ do
					local footprintKey = makeColumnKey(centerX + dx, centerZ + dz)
					if reservedKeys[footprintKey] ~= true then
						reservedKeys[footprintKey] = true
						table.insert(footprintKeys, footprintKey)
					end
				end
			end
			return footprintKeys
		end

		local function findAssemblyComponentColumn(
			anchorX: number,
			anchorZ: number,
			componentDX: number,
			componentDZ: number,
			prefabId: string,
			anchorHeight: number,
			reservedKeys: { [string]: boolean }
		): TileColumn?
			local targetX = anchorX + componentDX
			local targetZ = anchorZ + componentDZ
			local bestColumn: TileColumn? = nil
			local bestScore = math.huge

			for dz = -assemblySearchRadius, assemblySearchRadius do
				for dx = -assemblySearchRadius, assemblySearchRadius do
					if (dx * dx + dz * dz) > assemblySearchRadiusSq then
						continue
					end

					local candidateKey = makeColumnKey(targetX + dx, targetZ + dz)
					if reservedKeys[candidateKey] or assignedNodeColumns[candidateKey] then
						continue
					end
					if assemblyLockInEnabled and lockedStructureColumns[candidateKey] then
						continue
					end

					local candidate = columns[candidateKey]
					if not isStructurePlacementColumnValid(candidate) then
						continue
					end
					if
						not canPlacePrefabFootprintAt(candidate.X, candidate.Z, prefabId, anchorHeight, reservedKeys)
					then
						continue
					end

					local heightDelta = math.abs(candidate.SurfaceY - anchorHeight)
					if heightDelta > assemblyMaxHeightDelta then
						continue
					end

					local score = (dx * dx + dz * dz) + (heightDelta * 0.35)
					if score < bestScore then
						bestScore = score
						bestColumn = candidate
					end
				end
			end

			return bestColumn
		end

		local function tryPlaceAssemblyNearNode(nodeX: number, nodeZ: number, biome: string): boolean
			if not assemblyPlacementEnabled then
				return false
			end

			local pool, weights = getRuntimeNodeAssemblyPool(biome)
			local assemblyId = chooseWeightedRuntimePrefabId(pool, weights, nodeStructureRng)
			if not assemblyId then
				return false
			end

			local assembly = RuntimeNodeAssemblyDefinitions[assemblyId]
			if not assembly or type(assembly.Components) ~= "table" or #assembly.Components <= 0 then
				return false
			end

			local anchorCandidates = {} :: {
				{
					X: number,
					Z: number,
					DistanceSq: number,
					SortToken: number,
					Column: TileColumn,
				}
			}
			for dz = -assemblySearchRadius, assemblySearchRadius do
				for dx = -assemblySearchRadius, assemblySearchRadius do
					local distanceSq = dx * dx + dz * dz
					if distanceSq > assemblySearchRadiusSq then
						continue
					end
					local anchorKey = makeColumnKey(nodeX + dx, nodeZ + dz)
					if assignedNodeColumns[anchorKey] then
						continue
					end
					if assemblyLockInEnabled and lockedStructureColumns[anchorKey] then
						continue
					end
					local anchorColumn = columns[anchorKey]
					if not isStructurePlacementColumnValid(anchorColumn) then
						continue
					end
					table.insert(anchorCandidates, {
						X = nodeX + dx,
						Z = nodeZ + dz,
						DistanceSq = distanceSq,
						SortToken = nodeStructureRng:NextNumber(),
						Column = anchorColumn,
					})
				end
			end

			table.sort(anchorCandidates, function(a, b)
				if a.DistanceSq == b.DistanceSq then
					return a.SortToken < b.SortToken
				end
				return a.DistanceSq < b.DistanceSq
			end)

			for _, anchor in ipairs(anchorCandidates) do
				local reserved = {} :: { [string]: boolean }
				local placementPlan =
					{} :: { { Key: string, Column: TileColumn, PrefabId: string, FootprintKeys: { string } } }
				local failedRequiredComponent = false

				for _, component in ipairs(assembly.Components) do
					local dx = if type(component.DX) == "number" then math.floor(component.DX + 0.5) else 0
					local dz = if type(component.DZ) == "number" then math.floor(component.DZ + 0.5) else 0
					local prefabId = if type(component.PrefabId) == "string" then component.PrefabId else ""
					local required = component.Required == true
					if prefabId == "" or PrefabRegistry.GetById(prefabId) == nil then
						if required then
							failedRequiredComponent = true
							break
						end
						continue
					end

					local componentColumn = findAssemblyComponentColumn(
						anchor.X,
						anchor.Z,
						dx,
						dz,
						prefabId,
						anchor.Column.SurfaceY,
						reserved
					)
					if not componentColumn then
						if required then
							failedRequiredComponent = true
							break
						end
						continue
					end

					local componentKey = makeColumnKey(componentColumn.X, componentColumn.Z)
					local footprintKeys =
						reservePrefabFootprint(reserved, componentColumn.X, componentColumn.Z, prefabId)
					table.insert(placementPlan, {
						Key = componentKey,
						Column = componentColumn,
						PrefabId = prefabId,
						FootprintKeys = footprintKeys,
					})
				end

				if failedRequiredComponent or #placementPlan <= 0 then
					continue
				end

				for _, placement in ipairs(placementPlan) do
					placement.Column.StructureTag = placement.PrefabId
					assignedNodeColumns[placement.Key] = true
					for _, footprintKey in ipairs(placement.FootprintKeys) do
						local footprintColumn = columns[footprintKey]
						if footprintColumn and footprintColumn.StructureTag ~= nil then
							local existingDefinition = PrefabRegistry.GetById(footprintColumn.StructureTag)
							if existingDefinition and existingDefinition.Category == "Nature" then
								footprintColumn.StructureTag = nil
							end
						end
						assignedNodeColumns[footprintKey] = true
						if assemblyLockInEnabled then
							lockedStructureColumns[footprintKey] = true
						end
					end
				end
				local nodeKey = makeColumnKey(nodeX, nodeZ)
				assignedNodeColumns[nodeKey] = true
				if assemblyLockInEnabled then
					lockedStructureColumns[nodeKey] = true
				end
				return true
			end

			return false
		end

		local function assignSingleNodeStructure(column: TileColumn): boolean
			local key = makeColumnKey(column.X, column.Z)
			if assignedNodeColumns[key] then
				return false
			end
			if assemblyLockInEnabled and lockedStructureColumns[key] then
				return false
			end
			if not canReplaceColumnStructure(column) then
				return false
			end

			local pool, weights = getRuntimeNodePool(column.Biome)
			local chosenTag = chooseWeightedRuntimePrefabId(pool, weights, nodeStructureRng)
			if not chosenTag then
				return false
			end
			if PrefabRegistry.GetById(chosenTag) == nil then
				return false
			end
			if not canPlacePrefabFootprintAt(column.X, column.Z, chosenTag, column.SurfaceY, {}) then
				return false
			end

			column.StructureTag = chosenTag
			assignedNodeColumns[key] = true
			local reservedFootprint = {} :: { [string]: boolean }
			local footprintKeys = reservePrefabFootprint(reservedFootprint, column.X, column.Z, chosenTag)
			for _, footprintKey in ipairs(footprintKeys) do
				local footprintColumn = columns[footprintKey]
				if footprintColumn and footprintColumn.StructureTag ~= nil then
					local existingDefinition = PrefabRegistry.GetById(footprintColumn.StructureTag)
					if existingDefinition and existingDefinition.Category == "Nature" then
						footprintColumn.StructureTag = nil
					end
				end
				assignedNodeColumns[footprintKey] = true
			end
			if assemblyLockInEnabled then
				for _, footprintKey in ipairs(footprintKeys) do
					lockedStructureColumns[footprintKey] = true
				end
			end
			return true
		end

		local function assignStructureCluster(nodeX: number, nodeZ: number, column: TileColumn): boolean
			if tryPlaceAssemblyNearNode(nodeX, nodeZ, column.Biome) then
				return true
			end
			return assignSingleNodeStructure(column)
		end

		for _, route in ipairs(allRoutes) do
			for nodeIndex, node in ipairs(route) do
				local shouldBeStructureNode = (#route == 1)
					or (nodeIndex == 1)
					or (nodeIndex > 1 and nodeIndex < #route and node.IsStructureNode == true)
				if not shouldBeStructureNode then
					continue
				end

				local key = makeColumnKey(node.X, node.Z)
				if assignedNodeColumns[key] then
					continue
				end
				local column = columns[key]
				if not column or not column.Solid or column.HasWater then
					continue
				end

				assignStructureCluster(node.X, node.Z, column)
			end
		end

		local ambientCount = math.max(0, math.floor(TerrainTuning.AmbientStructureNodeCount + 0.5))
		local ambientAttempts = math.max(ambientCount, math.floor(TerrainTuning.AmbientStructureNodeAttempts + 0.5))
		local ambientMinSpacing = math.max(3, TerrainTuning.AmbientStructureNodeMinSpacing)
		local ambientMinSpacingSq = ambientMinSpacing * ambientMinSpacing
		local ambientPicked = 0
		local ambientPlaced = {} :: { { X: number, Z: number } }
		local maxAmbientSlope = 1.65

		local function hasAmbientSpacing(x: number, z: number): boolean
			for _, placed in ipairs(ambientPlaced) do
				local dx = placed.X - x
				local dz = placed.Z - z
				if (dx * dx + dz * dz) < ambientMinSpacingSq then
					return false
				end
			end
			return true
		end

		local function isAmbientStructureCandidateFlat(column: TileColumn): boolean
			local totalSlope = 0
			local count = 0
			for _, offset in ipairs({
				{ 1, 0 },
				{ -1, 0 },
				{ 0, 1 },
				{ 0, -1 },
			}) do
				local neighbor = columns[makeColumnKey(column.X + offset[1], column.Z + offset[2])]
				if neighbor and neighbor.Solid then
					totalSlope += math.abs(neighbor.SurfaceY - column.SurfaceY)
					count += 1
				end
			end
			if count == 0 then
				return false
			end
			local averageSlope = totalSlope / count
			return averageSlope <= maxAmbientSlope
		end

		for _ = 1, ambientAttempts do
			if ambientPicked >= ambientCount then
				break
			end
			local x = nodeStructureRng:NextInteger(-config.RadiusTiles, config.RadiusTiles)
			local z = nodeStructureRng:NextInteger(-config.RadiusTiles, config.RadiusTiles)
			local key = makeColumnKey(x, z)
			if assignedNodeColumns[key] then
				continue
			end
			if assemblyLockInEnabled and lockedStructureColumns[key] then
				continue
			end
			local column = columns[key]
			if not column or not column.Solid or column.HasWater then
				continue
			end
			if not canReplaceColumnStructure(column) then
				continue
			end
			if not isAmbientStructureCandidateFlat(column) then
				continue
			end
			if not hasAmbientSpacing(x, z) then
				continue
			end
			if assignStructureCluster(x, z, column) then
				ambientPicked += 1
				table.insert(ambientPlaced, { X = x, Z = z })
			end
		end
	end

	-- Bridge structure tags are intentionally disabled for prefab-only runtime scenery.

	return startColumn, endpoints, #usedNodes, allRoutes
end
