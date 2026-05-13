--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

local CARDINAL_NEIGHBOR_OFFSETS = {
	{ DX = 1, DZ = 0 },
	{ DX = -1, DZ = 0 },
	{ DX = 0, DZ = 1 },
	{ DX = 0, DZ = -1 },
}

local ALL_NEIGHBOR_OFFSETS = {
	{ DX = 1, DZ = 0 },
	{ DX = -1, DZ = 0 },
	{ DX = 0, DZ = 1 },
	{ DX = 0, DZ = -1 },
	{ DX = 1, DZ = 1 },
	{ DX = 1, DZ = -1 },
	{ DX = -1, DZ = 1 },
	{ DX = -1, DZ = -1 },
}

local function makeColumnKey(x: number, z: number): string
	return tostring(x) .. ":" .. tostring(z)
end

local function countCandidateNeighbors(
	candidateByKey: { [string]: boolean },
	x: number,
	z: number,
	offsets: { { DX: number, DZ: number } }
): number
	local count = 0
	for _, offset in ipairs(offsets) do
		local neighborKey = makeColumnKey(x + offset.DX, z + offset.DZ)
		if candidateByKey[neighborKey] then
			count += 1
		end
	end
	return count
end

local function smoothCandidateMap(
	columns: { [string]: TileColumn },
	candidateByKey: { [string]: boolean },
	passes: number,
	maxSurfaceY: number
): { [string]: boolean }
	for _ = 1, passes do
		local nextMap = {} :: { [string]: boolean }
		for key, column in pairs(columns) do
			if not column.Solid or column.SurfaceY > maxSurfaceY then
				continue
			end
			local neighborCount = countCandidateNeighbors(candidateByKey, column.X, column.Z, ALL_NEIGHBOR_OFFSETS)
			local isCandidate = candidateByKey[key] == true
			if isCandidate then
				if neighborCount >= 2 then
					nextMap[key] = true
				end
			elseif neighborCount >= 5 then
				nextMap[key] = true
			end
		end
		candidateByKey = nextMap
	end
	return candidateByKey
end

local function retainLargePoolComponents(
	columns: { [string]: TileColumn },
	candidateByKey: { [string]: boolean },
	minPoolSize: number
): { [string]: boolean }
	local kept = {} :: { [string]: boolean }
	local visited = {} :: { [string]: boolean }

	for key, isCandidate in pairs(candidateByKey) do
		if not isCandidate or visited[key] then
			continue
		end

		local componentKeys = {} :: { string }
		local queue = { key }
		local head = 1
		visited[key] = true

		while head <= #queue do
			local currentKey = queue[head]
			head += 1
			table.insert(componentKeys, currentKey)

			local column = columns[currentKey]
			if column then
				for _, offset in ipairs(CARDINAL_NEIGHBOR_OFFSETS) do
					local neighborKey = makeColumnKey(column.X + offset.DX, column.Z + offset.DZ)
					if candidateByKey[neighborKey] and not visited[neighborKey] then
						visited[neighborKey] = true
						table.insert(queue, neighborKey)
					end
				end
			end
		end

		if #componentKeys >= minPoolSize then
			for _, componentKey in ipairs(componentKeys) do
				kept[componentKey] = true
			end
		end
	end

	return kept
end

local function expandPools(
	columns: { [string]: TileColumn },
	candidateByKey: { [string]: boolean },
	maxSurfaceY: number,
	seed: number,
	fringeNoiseX: number,
	fringeNoiseZ: number
): { [string]: boolean }
	local expanded = {} :: { [string]: boolean }
	for key, value in pairs(candidateByKey) do
		if value then
			expanded[key] = true
		end
	end

	for key, column in pairs(columns) do
		if not column.Solid or candidateByKey[key] then
			continue
		end
		if column.SurfaceY > maxSurfaceY + 1 then
			continue
		end

		local neighborCount = countCandidateNeighbors(candidateByKey, column.X, column.Z, CARDINAL_NEIGHBOR_OFFSETS)
		if neighborCount >= 2 then
			expanded[key] = true
		elseif neighborCount == 1 then
			local fringeNoise =
				math.noise((column.X + fringeNoiseX) * 0.19, (column.Z + fringeNoiseZ) * 0.19, seed * 0.0027)
			if fringeNoise > 0.56 then
				expanded[key] = true
			end
		end
	end

	return expanded
end

return function(ctx, columns, config, seed)
	local getBiomeMaterials = ctx.getBiomeMaterials

	local waterNoiseX = (seed % 7919) * 0.07
	local waterNoiseZ = (seed % 6361) * 0.05
	local basinNoiseX = (seed % 9929) * 0.041
	local basinNoiseZ = (seed % 8191) * 0.037
	local fringeNoiseX = (seed % 5501) * 0.053
	local fringeNoiseZ = (seed % 4201) * 0.047

	local waterSurfaceY = config.BaseY + config.SeaLevel
	local maxSurfaceY = waterSurfaceY + 5

	local candidateByKey = {} :: { [string]: boolean }
	for key, column in pairs(columns) do
		if not column.Solid or column.SurfaceY > maxSurfaceY then
			continue
		end

		local pondNoise = math.noise((column.X + waterNoiseX) * 0.11, (column.Z + waterNoiseZ) * 0.11, seed * 0.0019)
		local basinNoise = math.noise((column.X + basinNoiseX) * 0.052, (column.Z + basinNoiseZ) * 0.052, seed * 0.0013)
		local detailNoise =
			math.noise((column.X - waterNoiseZ) * 0.21, (column.Z + waterNoiseX) * 0.21, (seed + 199) * 0.0021)
		local isPondCandidate = pondNoise > 0.24 and basinNoise > 0.04 and detailNoise > -0.18
		if isPondCandidate then
			candidateByKey[key] = true
		end
	end

	candidateByKey = smoothCandidateMap(columns, candidateByKey, 2, maxSurfaceY)
	candidateByKey = retainLargePoolComponents(columns, candidateByKey, 12)
	candidateByKey = expandPools(columns, candidateByKey, maxSurfaceY, seed, fringeNoiseX, fringeNoiseZ)

	for key, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		if candidateByKey[key] then
			local materials = getBiomeMaterials(column.Biome)
			column.HasWater = true
			column.SurfaceMaterial = materials.Water
			column.StructureTag = nil
		else
			column.HasWater = false
		end
	end
end
