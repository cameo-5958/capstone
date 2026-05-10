--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local endpoint = script.Parent:FindFirstChild("WorldEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "WorldEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent
local WorldTypes = require(script.Parent.WorldTypes)
local PrefabRegistry = require(script.Parent.Prefabs.PrefabRegistry)

type WorldConfig = {
	Seed: number,
	TileSize: number,
	ChunkSize: number,
	RadiusTiles: number,
	BaseY: number,
	Biome: string,
	SeaLevel: number,
	OceanMode: string,
}

type TileColumn = {
	X: number,
	Z: number,
	Solid: boolean,
	Biome: string,
	IsPath: boolean,
	SurfaceY: number,
	BottomY: number,
	SurfaceMaterial: Enum.Material,
	PathMaterial: Enum.Material?,
	FillMaterial: Enum.Material,
	HasWater: boolean,
	StructureTag: string?,
}

type TileColumnPayload = {
	X: number,
	Z: number,
	Solid: boolean,
	Biome: string,
	IsPath: boolean,
	SurfaceY: number,
	BottomY: number,
	SurfaceMaterial: string,
	PathMaterial: string?,
	FillMaterial: string,
	HasWater: boolean,
	StructureTag: string?,
}

type ChunkData = {
	ChunkX: number,
	ChunkZ: number,
	Columns: { TileColumnPayload },
}

type WorldState = {
	Seed: number,
	Config: WorldConfig,
	Columns: { [string]: TileColumn },
	Chunks: { ChunkData },
	ChunkLookup: { [string]: ChunkData },
	CollisionParts: number,
	PathStart: TileColumn?,
	PathEndpoints: { TileColumn },
	PathNodeCount: number,
	PathRoutes: { { { X: number, Z: number, Height: number, RadiusScale: number } } },
}

type DepthAnchor = {
	X: number,
	Z: number,
	Radius: number,
	Depth: number,
}

type PathPoint = {
	X: number,
	Z: number,
	Height: number,
	RadiusScale: number,
}

type PathRoute = { PathPoint }

type ChunkDistance = {
	Chunk: ChunkData,
	DistanceSq: number,
}

type BiomeChunkInfo = {
	ChunkX: number,
	ChunkZ: number,
	CenterX: number,
	CenterZ: number,
	SumHeight: number,
	SumDistance: number,
	Count: number,
	AvgHeight: number,
	Temperature: number,
	Moisture: number,
	Biome: string,
}

local WorldServiceServer = {}

local WorldRoot: Folder? = nil
local VisualRoot: Folder? = nil
local CollisionRoot: Folder? = nil
local ActiveSpawnLocation: SpawnLocation? = nil

local CurrentSeed = 0
local CurrentWorld: WorldState? = nil

local TerrainTuning = {
	MountainRingStart = 0.2,
	MountainRingEnd = 0.9,
	MountainBaseHeight = 48,
	MountainPeakBase = 20,
	MountainPeakScale = 34,
	MountainWallLift = 16,
	CanyonNoiseLow = 0.05,
	CanyonNoiseHigh = 0.2,
	CanyonSpokeBaseWidth = 0.07,
	CanyonSpokeScaleWidth = 0.24,
	CanyonFloorCenterLift = 3,
	CanyonFloorNoiseAmplitude = 2,
	ThicknessBase = 44,
	ThicknessCenterScale = 82,
	ThicknessNoiseScale = 6,
	ThicknessMin = 40,
	ThicknessAnchorCount = 9,
	ThicknessAnchorDepthMin = 58,
	ThicknessAnchorDepthMax = 140,
	ThicknessAnchorRadiusMin = 0.38,
	ThicknessAnchorRadiusMax = 0.76,
	ThicknessAnchorInnerInfluence = 0.12,
	ThicknessSmoothPasses = 2,
	PathEndpointCount = 3,
	PathEndpointRadiusMin = 0.72,
	PathEndpointRadiusMax = 0.92,
	PathWanderStrength = 1.2,
	PathWanderSecondaryStrength = 0.65,
	PathWanderForwardStrength = 0.35,
	PathStepTiles = 1,
	PathHalfWidth = 2.8,
	PathShoulderWidth = 6.5,
	PathMountainCliffRise = 14,
	PathForestClearingWidth = 2.6,
	PathFlattenNoiseAmplitude = 0,
	MountainBridgeChance = 0.08,
	MountainBridgeMinGapDrop = 4,
	MountainBridgeMinSpacing = 8,
	PathNodeHeightBlendStrength = 0.9,
	PathNodeFlattenStrength = 0.92,
	PathNodeFlattenRadiusMultiplier = 1.75,
	PathNodeFlattenCore = 0.3,
	PathNodeFlattenSmoothingPasses = 3,
	PathNodeSpacing = 10,
	PathNodeSearchRadius = 5,
	PathNodePlacementAttempts = 18,
	PathNodeLateralJitter = 10.5,
	PathNodeSegmentLength = 14,
	PathNodeRadiusScaleMin = 1,
	PathNodeRadiusScaleMax = 2,
	PathNodeTargetGoalBlend = 0.72,
	PathNodeTargetLocalBlend = 0.4,
	PathNodeRisePerTile = 0.18,
	PathNodeFallPerTile = 0.22,
	PathNodeHeightJitter = 0.12,
	PathNodeHeightSmoothingPasses = 4,
	PathNodeHeightSmoothingBlend = 0.62,
	CityNodeCount = 4,
	CityPlacementAttempts = 24,
	CityRadiusMin = 0.34,
	CityRadiusMax = 0.9,
	CityNodeSpacingMultiplier = 1.4,
	CityNodeRadiusScaleMin = 2.2,
	CityNodeRadiusScaleMax = 3.4,
	CityFlattenEdgeInnerRatio = 0.72,
	CityFlattenEdgeOuterRatio = 1.3,
	CityFlattenEdgeBlend = 0.82,
	PathEdgeBlend = 0.42,
	PathEdgeSampleRadius = 3,
	BiomeChunkTileSpan = 26,
	BiomeChunkJitter = 0.34,
	BiomeChunkBlendWidth = 6.5,
	BiomeChunkClimateScale = 0.012,
	BiomeChunkDetailScale = 0.031,
	BiomeEdgeSmoothingStart = 0.45,
	BiomeEdgeSmoothingEnd = 1.05,
	BiomeSmoothPasses = 2,
	SurfaceSmoothPasses = 2,
	SurfaceSmoothBlend = 0.36,
	SurfaceSmoothMountainBlend = 0.22,
	SurfaceSmoothCoastBoost = 0.26,
	SurfaceSmoothPathBlend = 0.55,
	SurfaceSmoothMaxStep = 2,
	SurfaceSmoothSpikeDelta = 2,
	PathConnectivityBridgePasses = 2,
	PathContinuityPasses = 7,
	PathContinuityBlendAlpha = 0.74,
	PathMaxNeighborStep = 1,
	MountainPathFloorSearchRadius = 6,
	MountainPathFloorOffset = 1,
	MountainPathSmoothingPasses = 2,
	SupportSearchRadius = 10,
	SupportIslandMinRadius = 3.8,
	SupportIslandExtraRadius = 2.9,
	SupportIslandThickness = 62,
	SupportBridgeHalfWidth = 2.8,
	SupportBridgeThickness = 58,
	SupportBridgeEdgeDrop = 3.2,
	EdgeDampenStart = 0.65,
	EdgeDampenEnd = 0.98,
	EdgeDampenCurve = 2.2,
	EdgeDampenHeightOffset = 1.0,
}

local StreamingTuning = {
	InitialChunkBurst = 56,
	MaxChunkRequestsPerMessage = 32,
	SuggestedStreamRadius = 22,
	SuggestedUnloadRadius = 28,
}

local RuntimeStructureChanceByBiome: { [string]: number } = {
	TemperateGrassland = 0.096,
	PineHighlands = 0.112,
	Forest = 0.138,
	DenseForest = 0.164,
	Alpine = 0.082,
	HighlandDesert = 0.074,
	Marshland = 0.122,
}

local RuntimeStructureWeightsByBiome: { [string]: { number } } = {
	TemperateGrassland = { 42, 34, 10, 7, 4, 3 },
	PineHighlands = { 44, 32, 9, 6, 5, 4 },
	Forest = { 46, 30, 10, 7, 4, 3 },
	DenseForest = { 38, 34, 11, 8, 5, 4 },
	Alpine = { 43, 31, 10, 7, 5, 4 },
	HighlandDesert = { 40, 32, 11, 7, 6, 4 },
	Marshland = { 44, 31, 10, 7, 5, 3 },
}

local NodeStructurePrefabIds = {}

local function makeColumnKey(x: number, z: number): string
	return tostring(x) .. ":" .. tostring(z)
end

local function hashStringToSeed(value: string): number
	local hash = 2166136261
	for index = 1, #value do
		hash = bit32.bxor(hash, string.byte(value, index))
		hash = (hash * 16777619) % 2147483647
	end
	return math.max(1, hash)
end

local function deriveServerSeed(): number
	if not RunService:IsStudio() and game.JobId ~= "" then
		return hashStringToSeed(game.JobId)
	end

	local stamp = DateTime.now().UnixTimestampMillis
	local fallback = math.abs(stamp % 2147483647)
	if fallback == 0 then
		fallback = 1
	end
	return fallback
end

local function getBiomeMaterials(biome: string)
	local biomeMaterials = WorldTypes.BiomeMaterials[biome]
	if biomeMaterials then
		return biomeMaterials
	end

	return WorldTypes.BiomeMaterials.TemperateGrassland
end

local function ensureWorldRoots()
	if WorldRoot and WorldRoot.Parent then
		return
	end

	local root = Workspace:FindFirstChild("WorldService")
	if not root then
		root = Instance.new("Folder")
		root.Name = "WorldService"
		root.Parent = Workspace
	end

	local visuals = root:FindFirstChild("VisualRoot")
	if not visuals then
		visuals = Instance.new("Folder")
		visuals.Name = "VisualRoot"
		visuals.Parent = root
	end

	local collision = root:FindFirstChild("CollisionRoot")
	if not collision then
		collision = Instance.new("Folder")
		collision.Name = "CollisionRoot"
		collision.Parent = root
	end

	WorldRoot = root :: Folder
	VisualRoot = visuals :: Folder
	CollisionRoot = collision :: Folder
end

local function clearCollisionRoot()
	if not CollisionRoot then
		return
	end

	for _, child in ipairs(CollisionRoot:GetChildren()) do
		child:Destroy()
	end
end

local function updateDebugHarness(world: WorldState)
	if not WorldRoot then
		return
	end

	local harness = WorldRoot:FindFirstChild("TestHarness")
	if not harness then
		harness = Instance.new("Part")
		harness.Name = "TestHarness"
		harness.Anchored = true
		harness.CanCollide = false
		harness.Material = Enum.Material.Neon
		harness.Color = Color3.fromRGB(101, 255, 165)
		harness.Transparency = 0.35
		harness.Size = Vector3.new(8, 1, 8)
		harness.Parent = WorldRoot
	end

	local topY = world.Config.BaseY
	for _, column in pairs(world.Columns) do
		if column.Solid then
			local isCenter = column.X == 0 and column.Z == 0
			if isCenter then
				topY = column.SurfaceY
				break
			end
		end
	end

	local harnessPart = harness :: Part
	harnessPart.Position = Vector3.new(0, topY + 5, 0)
	harnessPart:SetAttribute("WorldSeed", world.Seed)
	harnessPart:SetAttribute("ChunkCount", #world.Chunks)
	harnessPart:SetAttribute("CollisionPartCount", world.CollisionParts)
	harnessPart:SetAttribute("PathEndpointCount", #world.PathEndpoints)
	harnessPart:SetAttribute("PathNodeCount", world.PathNodeCount)
	if world.PathStart then
		harnessPart:SetAttribute("PathStartX", world.PathStart.X)
		harnessPart:SetAttribute("PathStartZ", world.PathStart.Z)
	end
end

local function getPreferredSpawnColumn(world: WorldState): TileColumn?
	if world.PathStart then
		return world.PathStart
	end

	local best: TileColumn? = nil
	local bestDistanceSq = math.huge

	for _, column in pairs(world.Columns) do
		if column.Solid and not column.HasWater then
			local distanceSq = column.X * column.X + column.Z * column.Z
			if distanceSq < bestDistanceSq then
				best = column
				bestDistanceSq = distanceSq
			end
		end
	end

	if best then
		return best
	end

	for _, column in pairs(world.Columns) do
		if column.Solid then
			local distanceSq = column.X * column.X + column.Z * column.Z
			if distanceSq < bestDistanceSq then
				best = column
				bestDistanceSq = distanceSq
			end
		end
	end

	return best
end

local function updateSpawnLocation(world: WorldState)
	if not WorldRoot then
		return
	end

	local existing = WorldRoot:FindFirstChild("IslandSpawnPoint")
	if existing and not existing:IsA("SpawnLocation") then
		existing:Destroy()
		existing = nil
	end

	if not existing then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "IslandSpawnPoint"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.AllowTeamChangeOnTouch = false
		spawn.CanCollide = false
		spawn.CanTouch = false
		spawn.Material = Enum.Material.Neon
		spawn.Color = Color3.fromRGB(110, 220, 255)
		spawn.Transparency = 0.15
		local spawnSize = math.max(10, world.Config.TileSize * 2)
		spawn.Size = Vector3.new(spawnSize, 1, spawnSize)
		spawn.Parent = WorldRoot
		existing = spawn
	end

	local spawnLocation = existing :: SpawnLocation
	local spawnColumn = getPreferredSpawnColumn(world)
	local tileSize = world.Config.TileSize
	local spawnX = if spawnColumn then spawnColumn.X * tileSize else 0
	local spawnZ = if spawnColumn then spawnColumn.Z * tileSize else 0
	local topY = if spawnColumn then spawnColumn.SurfaceY else world.Config.BaseY
	local yOffset = spawnLocation.Size.Y * 0.5 + 3
	spawnLocation.Position = Vector3.new(spawnX, topY + yOffset, spawnZ)
	spawnLocation:SetAttribute("WorldSeed", world.Seed)

	ActiveSpawnLocation = spawnLocation
	for _, player in ipairs(Players:GetPlayers()) do
		player.RespawnLocation = spawnLocation
	end
end

local function teleportPlayerToSpawn(player: Player)
	if not ActiveSpawnLocation then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local spawnPart = ActiveSpawnLocation
	local targetPosition = spawnPart.Position + Vector3.new(0, 4, 0)
	local lookVector = Vector3.new(spawnPart.CFrame.LookVector.X, 0, spawnPart.CFrame.LookVector.Z)
	if lookVector.Magnitude < 0.001 then
		lookVector = Vector3.new(0, 0, -1)
	else
		lookVector = lookVector.Unit
	end

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(targetPosition, targetPosition + lookVector))
end

local function makeDefaultConfig(seed: number): WorldConfig
	return {
		Seed = seed,
		TileSize = WorldTypes.DefaultConfig.TileSize,
		ChunkSize = WorldTypes.DefaultConfig.ChunkSize,
		RadiusTiles = WorldTypes.DefaultConfig.RadiusTiles,
		BaseY = WorldTypes.DefaultConfig.BaseY,
		Biome = WorldTypes.DefaultConfig.Biome,
		SeaLevel = WorldTypes.DefaultConfig.SeaLevel,
		OceanMode = WorldTypes.DefaultConfig.OceanMode,
	}
end

local function createEmptyColumns(config: WorldConfig): { [string]: TileColumn }
	local columns = {} :: { [string]: TileColumn }
	local materials = getBiomeMaterials(config.Biome)

	for x = -config.RadiusTiles, config.RadiusTiles do
		for z = -config.RadiusTiles, config.RadiusTiles do
			columns[makeColumnKey(x, z)] = {
				X = x,
				Z = z,
				Solid = false,
				Biome = config.Biome,
				IsPath = false,
				SurfaceY = config.BaseY,
				BottomY = config.BaseY - 4,
				SurfaceMaterial = materials.Surface,
				PathMaterial = nil,
				FillMaterial = materials.Mid,
				HasWater = false,
				StructureTag = nil,
			}
		end
	end

	return columns
end

local function rotate2D(x: number, z: number, cosAngle: number, sinAngle: number): (number, number)
	return x * cosAngle - z * sinAngle, x * sinAngle + z * cosAngle
end

local function smoothstep(edge0: number, edge1: number, value: number): number
	if edge0 == edge1 then
		return if value < edge0 then 0 else 1
	end

	local t = math.clamp((value - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function angularDistance(a: number, b: number): number
	return math.abs(math.atan2(math.sin(a - b), math.cos(a - b)))
end

local function getSolidColumnNear(columns: { [string]: TileColumn }, x: number, z: number, maxRadius: number): TileColumn?
	for radius = 0, maxRadius do
		for dx = -radius, radius do
			for dz = -radius, radius do
				local column = columns[makeColumnKey(x + dx, z + dz)]
				if column and column.Solid then
					return column
				end
			end
		end
	end

	return nil
end

local function getCenterSolidColumn(columns: { [string]: TileColumn }): TileColumn?
	local best: TileColumn? = nil
	local bestDistanceSq = math.huge

	for _, column in pairs(columns) do
		if column.Solid and not column.HasWater then
			local distanceSq = column.X * column.X + column.Z * column.Z
			if distanceSq < bestDistanceSq then
				best = column
				bestDistanceSq = distanceSq
			end
		end
	end

	if best then
		return best
	end

	for _, column in pairs(columns) do
		if column.Solid then
			local distanceSq = column.X * column.X + column.Z * column.Z
			if distanceSq < bestDistanceSq then
				best = column
				bestDistanceSq = distanceSq
			end
		end
	end

	return best
end

local function getNearestSolidColumnToTarget(
	columns: { [string]: TileColumn },
	targetX: number,
	targetZ: number,
	minDistanceSqFromStart: number?,
	startColumn: TileColumn?
): TileColumn?
	local best: TileColumn? = nil
	local bestScore = math.huge

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		if startColumn and minDistanceSqFromStart then
			local sdx = column.X - startColumn.X
			local sdz = column.Z - startColumn.Z
			local fromStartSq = sdx * sdx + sdz * sdz
			if fromStartSq < minDistanceSqFromStart then
				continue
			end
		end

		local dx = column.X - targetX
		local dz = column.Z - targetZ
		local score = dx * dx + dz * dz
		if score < bestScore then
			best = column
			bestScore = score
		end
	end

	return best
end

local function hasNodeOverlap(nodes: { PathPoint }, x: number, z: number, minSpacing: number): boolean
	local minSpacingSq = minSpacing * minSpacing
	for _, node in ipairs(nodes) do
		local dx = node.X - x
		local dz = node.Z - z
		if (dx * dx + dz * dz) < minSpacingSq then
			return true
		end
	end

	return false
end

local function randomNodeRadiusScale(rng: Random): number
	local minScale = TerrainTuning.PathNodeRadiusScaleMin
	local maxScale = TerrainTuning.PathNodeRadiusScaleMax
	if minScale > maxScale then
		minScale, maxScale = maxScale, minScale
	end
	return rng:NextNumber(minScale, maxScale)
end

local function tryPlaceNode(
	columns: { [string]: TileColumn },
	usedNodes: { PathPoint },
	rng: Random,
	desiredX: number,
	desiredZ: number
): PathPoint?
	local attempts = TerrainTuning.PathNodePlacementAttempts
	local searchRadius = TerrainTuning.PathNodeSearchRadius
	local jitter = TerrainTuning.PathNodeLateralJitter

	for _ = 1, attempts do
		local candidateX = desiredX + rng:NextNumber(-jitter, jitter)
		local candidateZ = desiredZ + rng:NextNumber(-jitter, jitter)
		local snappedColumn = getSolidColumnNear(columns, math.floor(candidateX + 0.5), math.floor(candidateZ + 0.5), searchRadius)
		if snappedColumn and not hasNodeOverlap(usedNodes, snappedColumn.X, snappedColumn.Z, TerrainTuning.PathNodeSpacing) then
			return {
				X = snappedColumn.X,
				Z = snappedColumn.Z,
				Height = snappedColumn.SurfaceY,
				RadiusScale = randomNodeRadiusScale(rng),
			}
		end
	end

	return nil
end

local function clampNodeHeightToColumn(columns: { [string]: TileColumn }, node: PathPoint, height: number): number
	local column = columns[makeColumnKey(node.X, node.Z)]
	if not column or not column.Solid then
		return height
	end

	local minHeight = column.BottomY + 2
	local maxHeight = column.SurfaceY
	if minHeight > maxHeight then
		return maxHeight
	end
	return math.clamp(height, minHeight, maxHeight)
end

local function applyGradualRouteNodeHeights(columns: { [string]: TileColumn }, route: { PathPoint }, seed: number)
	local nodeCount = #route
	if nodeCount < 2 then
		return
	end

	local goalBlend = math.clamp(TerrainTuning.PathNodeTargetGoalBlend, 0, 1)
	local localBlend = math.clamp(TerrainTuning.PathNodeTargetLocalBlend, 0, 1)
	if goalBlend + localBlend > 1 then
		local total = goalBlend + localBlend
		goalBlend = goalBlend / total
		localBlend = localBlend / total
	end
	local remainingBlend = math.max(0, 1 - goalBlend - localBlend)
	local risePerTile = math.max(0.01, TerrainTuning.PathNodeRisePerTile)
	local fallPerTile = math.max(0.01, TerrainTuning.PathNodeFallPerTile)
	local heightJitter = math.max(0, TerrainTuning.PathNodeHeightJitter)
	local smoothingPasses = math.max(0, TerrainTuning.PathNodeHeightSmoothingPasses)
	local smoothingBlend = math.clamp(TerrainTuning.PathNodeHeightSmoothingBlend, 0, 1)
	local cumulativeDistance = {} :: { number }
	cumulativeDistance[1] = 0
	local totalDistance = 0
	for nodeIndex = 2, nodeCount do
		local a = route[nodeIndex - 1]
		local b = route[nodeIndex]
		local dx = b.X - a.X
		local dz = b.Z - a.Z
		local segmentDistance = math.max(1, math.sqrt(dx * dx + dz * dz))
		totalDistance += segmentDistance
		cumulativeDistance[nodeIndex] = totalDistance
	end
	if totalDistance <= 0 then
		totalDistance = math.max(1, nodeCount - 1)
	end

	local startHeight = clampNodeHeightToColumn(columns, route[1], route[1].Height)
	local endHeight = clampNodeHeightToColumn(columns, route[nodeCount], route[nodeCount].Height)
	local targetHeights = {} :: { number }
	targetHeights[1] = startHeight
	for nodeIndex = 2, nodeCount do
		local node = route[nodeIndex]
		local progress = cumulativeDistance[nodeIndex] / totalDistance
		local goalHeight = startHeight + (endHeight - startHeight) * progress
		local column = columns[makeColumnKey(node.X, node.Z)]
		local localSurfaceHeight = if column and column.Solid then column.SurfaceY else node.Height
		local targetHeight = goalHeight * goalBlend + localSurfaceHeight * localBlend + node.Height * remainingBlend
		if nodeIndex < nodeCount and heightJitter > 0 then
			local jitterNoise = math.noise(
				(node.X + (seed % 947)) * 0.11,
				(node.Z - (seed % 557)) * 0.11,
				seed * 0.00171 + nodeIndex * 0.13
			) * heightJitter
			targetHeight += jitterNoise
		end
		targetHeights[nodeIndex] = clampNodeHeightToColumn(columns, node, targetHeight)
	end

	local function applySlopeConstraints()
		for nodeIndex = 2, nodeCount do
			local previousHeight = targetHeights[nodeIndex - 1]
			local currentHeight = targetHeights[nodeIndex]
			local segmentDistance = math.max(1, cumulativeDistance[nodeIndex] - cumulativeDistance[nodeIndex - 1])
			local minAllowed = previousHeight - fallPerTile * segmentDistance
			local maxAllowed = previousHeight + risePerTile * segmentDistance
			targetHeights[nodeIndex] = clampNodeHeightToColumn(columns, route[nodeIndex], math.clamp(currentHeight, minAllowed, maxAllowed))
		end

		for nodeIndex = nodeCount - 1, 2, -1 do
			local nextHeight = targetHeights[nodeIndex + 1]
			local currentHeight = targetHeights[nodeIndex]
			local segmentDistance = math.max(1, cumulativeDistance[nodeIndex + 1] - cumulativeDistance[nodeIndex])
			local minAllowed = nextHeight - risePerTile * segmentDistance
			local maxAllowed = nextHeight + fallPerTile * segmentDistance
			targetHeights[nodeIndex] = clampNodeHeightToColumn(columns, route[nodeIndex], math.clamp(currentHeight, minAllowed, maxAllowed))
		end
	end

	applySlopeConstraints()
	for _ = 1, smoothingPasses do
		local nextHeights = {} :: { number }
		nextHeights[1] = targetHeights[1]
		nextHeights[nodeCount] = targetHeights[nodeCount]
		for nodeIndex = 2, nodeCount - 1 do
			local previousHeight = targetHeights[nodeIndex - 1]
			local currentHeight = targetHeights[nodeIndex]
			local nextHeight = targetHeights[nodeIndex + 1]
			local averagedHeight = (previousHeight + currentHeight * 2 + nextHeight) * 0.25
			local smoothedHeight = currentHeight * (1 - smoothingBlend) + averagedHeight * smoothingBlend
			nextHeights[nodeIndex] = clampNodeHeightToColumn(columns, route[nodeIndex], smoothedHeight)
		end
		targetHeights = nextHeights
		applySlopeConstraints()
	end

	for nodeIndex, node in ipairs(route) do
		node.Height = targetHeights[nodeIndex]
	end
end

local function generateWindingPathNodes(
	columns: { [string]: TileColumn },
	startColumn: TileColumn,
	endColumn: TileColumn,
	usedNodes: { PathPoint },
	startRadiusScale: number,
	seed: number
): { PathPoint }
	local rng = Random.new(seed)
	local route = {} :: { PathPoint }
	local startNode = {
		X = startColumn.X,
		Z = startColumn.Z,
		Height = startColumn.SurfaceY,
		RadiusScale = startRadiusScale,
	}
	table.insert(route, startNode)
	local dx = endColumn.X - startColumn.X
	local dz = endColumn.Z - startColumn.Z
	local distance = math.max(1, math.sqrt(dx * dx + dz * dz))
	local segmentLength = math.max(3, TerrainTuning.PathNodeSegmentLength)
	local nodeCount = math.max(2, math.floor(distance / segmentLength))

	for nodeIndex = 1, nodeCount - 1 do
		local progress = nodeIndex / nodeCount
		local baseX = startColumn.X + dx * progress
		local baseZ = startColumn.Z + dz * progress
		local dirX = dx / distance
		local dirZ = dz / distance
		local perpX = -dirZ
		local perpZ = dirX
		local taper = math.sin(progress * math.pi)
		local primaryWander = math.noise(
			(baseX + (seed % 557)) * 0.12,
			(baseZ + (seed % 883)) * 0.12,
			seed * 0.00041 + nodeIndex * 0.09
		) * TerrainTuning.PathWanderStrength
		local secondaryWander = math.noise(
			(baseX - (seed % 239)) * 0.2,
			(baseZ + (seed % 349)) * 0.2,
			seed * 0.00077 + nodeIndex * 0.13
		) * TerrainTuning.PathWanderSecondaryStrength
		local wander = (primaryWander + secondaryWander) * taper
		local forwardShift = rng:NextNumber(-1, 1) * TerrainTuning.PathWanderForwardStrength * segmentLength * taper
		local desiredX = baseX + perpX * wander * TerrainTuning.PathNodeLateralJitter + dirX * forwardShift
		local desiredZ = baseZ + perpZ * wander * TerrainTuning.PathNodeLateralJitter + dirZ * forwardShift
		local placed = tryPlaceNode(columns, usedNodes, rng, desiredX, desiredZ)
		if placed then
			table.insert(route, placed)
			table.insert(usedNodes, placed)
		end
	end

	local endNodeCandidate = tryPlaceNode(columns, usedNodes, rng, endColumn.X, endColumn.Z)
	local endNode = if endNodeCandidate then endNodeCandidate else {
		X = endColumn.X,
		Z = endColumn.Z,
		Height = endColumn.SurfaceY,
		RadiusScale = randomNodeRadiusScale(rng),
	}
	if not endNodeCandidate and hasNodeOverlap(usedNodes, endNode.X, endNode.Z, TerrainTuning.PathNodeSpacing) then
		local fallbackColumn = getSolidColumnNear(columns, endColumn.X, endColumn.Z, TerrainTuning.PathNodeSearchRadius + 2)
		if fallbackColumn and not hasNodeOverlap(usedNodes, fallbackColumn.X, fallbackColumn.Z, TerrainTuning.PathNodeSpacing) then
			endNode = {
				X = fallbackColumn.X,
				Z = fallbackColumn.Z,
				Height = fallbackColumn.SurfaceY,
				RadiusScale = randomNodeRadiusScale(rng),
			}
		end
	end
	local canPlaceEndNode = not hasNodeOverlap(usedNodes, endNode.X, endNode.Z, TerrainTuning.PathNodeSpacing * 0.75)
	if canPlaceEndNode then
		table.insert(usedNodes, endNode)
		table.insert(route, endNode)
	end

	applyGradualRouteNodeHeights(columns, route, seed + 17)

	return route
end

local function runFootprintSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	local radius = math.max(config.RadiusTiles, 1)
	local angle = ((seed % 360) / 180) * math.pi
	local cosAngle = math.cos(angle)
	local sinAngle = math.sin(angle)

	local macroNoiseX = (seed % 1877) * 0.13
	local macroNoiseZ = (seed % 3251) * 0.11
	local detailNoiseX = (seed % 5623) * 0.07
	local detailNoiseZ = (seed % 4447) * 0.09
	local warpNoiseX = (seed % 7333) * 0.09
	local warpNoiseZ = (seed % 8971) * 0.08
	local coveNoiseX = (seed % 2687) * 0.15
	local coveNoiseZ = (seed % 3529) * 0.12
	local lobePhaseA = (seed % 360) * (math.pi / 180)
	local lobePhaseB = ((seed * 7) % 360) * (math.pi / 180)
	local lobePhaseC = ((seed * 13) % 360) * (math.pi / 180)
	local processedCount = 0

	for _, column in pairs(columns) do
		processedCount += 1
		if processedCount % 5000 == 0 then
			task.wait()
		end

		local rx, rz = rotate2D(column.X, column.Z, cosAngle, sinAngle)
		local nx = rx / radius
		local nz = rz / radius

		local radial = math.sqrt(nx * nx + nz * nz)
		if radial <= 0.2 then
			column.Solid = true
			continue
		end

		if radial >= 1.45 then
			column.Solid = false
			continue
		end

		local warpPrimary = math.noise((rx + warpNoiseX) * 0.065, (rz + warpNoiseZ) * 0.065, seed * 0.00037)
		local warpSecondary = math.noise((rx - warpNoiseZ) * 0.12, (rz + warpNoiseX) * 0.12, seed * 0.00073)
		local warpScale = 0.16 + math.max(0, radial - 0.38) * 0.2
		local warpedX = nx + warpPrimary * warpScale + warpSecondary * 0.08
		local warpedZ = nz + warpSecondary * warpScale - warpPrimary * 0.08
		local warpedRadius = math.sqrt(warpedX * warpedX + warpedZ * warpedZ)
		local warpedAngle = math.atan2(warpedZ, warpedX)

		local lobeA = math.sin(warpedAngle * 2.3 + lobePhaseA) * 0.16
		local lobeB = math.sin(warpedAngle * 4.9 + lobePhaseB) * 0.09
		local lobeC = math.sin(warpedAngle * 7.1 + lobePhaseC) * 0.05
		local macroNoise = math.noise((warpedX + macroNoiseX) * 1.28, (warpedZ + macroNoiseZ) * 1.28, seed * 0.00057) * 0.14
		local detailNoise = math.noise((warpedX - detailNoiseX) * 2.55, (warpedZ + detailNoiseZ) * 2.55, seed * 0.00101) * 0.06
		local coastline = math.clamp(0.93 + lobeA + lobeB + lobeC + macroNoise + detailNoise, 0.62, 1.36)
		local isSolid = warpedRadius <= coastline

		if isSolid and radial > 0.62 then
			local coveNoise = math.noise((warpedX + coveNoiseX) * 3.2, (warpedZ + coveNoiseZ) * 3.2, seed * 0.00183)
			local coveThreshold = 0.93 - math.clamp((radial - 0.62) / 0.6, 0, 1) * 0.2
			if coveNoise > coveThreshold then
				isSolid = false
			end
		end

		if not isSolid and radial <= 0.34 then
			isSolid = true
		end

		column.Solid = isSolid
	end
end

local function runHeightSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	local heightNoiseX = (seed % 1787) * 0.19
	local heightNoiseZ = (seed % 2677) * 0.11
	local mountainNoiseX = (seed % 8087) * 0.09
	local mountainNoiseZ = (seed % 7129) * 0.08
	local canyonNoiseX = (seed % 6211) * 0.12
	local canyonNoiseZ = (seed % 7481) * 0.1
	local pathNoiseX = (seed % 9151) * 0.06
	local pathNoiseZ = (seed % 8399) * 0.05
	local branchBaseAngle = ((seed % 360) / 180) * math.pi
	local branchAngles = {
		branchBaseAngle,
		branchBaseAngle + (math.pi * 2 / 3),
		branchBaseAngle + (math.pi * 4 / 3),
	}

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		local radialDistance = math.sqrt(column.X * column.X + column.Z * column.Z)
		local distance01 = math.clamp(radialDistance / config.RadiusTiles, 0, 1)
		local angle = math.atan2(column.Z, column.X)
		local coarseNoise = math.noise((column.X + heightNoiseX) * 0.1, (column.Z + heightNoiseZ) * 0.1, seed * 0.0007)
		local fineNoise = math.noise((column.X - heightNoiseZ) * 0.25, (column.Z + heightNoiseX) * 0.25, seed * 0.0011)
		local mountainNoise = math.noise((column.X + mountainNoiseX) * 0.07, (column.Z + mountainNoiseZ) * 0.07, seed * 0.0019)
		local peakMask = math.clamp((mountainNoise + 0.1) * 0.9, 0, 1)
		local mountainRing = smoothstep(TerrainTuning.MountainRingStart, TerrainTuning.MountainRingEnd, distance01)
		local mountainBase = mountainRing * TerrainTuning.MountainBaseHeight
		local peakBoost = (peakMask ^ 2) * (TerrainTuning.MountainPeakBase + mountainRing * TerrainTuning.MountainPeakScale)
		local mountainHeight = config.BaseY + mountainBase + coarseNoise * 7 + fineNoise * 3 + peakBoost

		local canyonNoise = math.abs(math.noise((column.X + canyonNoiseX) * 0.075, (column.Z + canyonNoiseZ) * 0.075, seed * 0.0016))
		local noiseCanyon = 1 - smoothstep(TerrainTuning.CanyonNoiseLow, TerrainTuning.CanyonNoiseHigh, canyonNoise)
		local spokeCanyon = 0
		local spokeWidth = TerrainTuning.CanyonSpokeBaseWidth + distance01 * TerrainTuning.CanyonSpokeScaleWidth
		for _, spokeAngle in ipairs(branchAngles) do
			local diff = angularDistance(angle, spokeAngle)
			local spokeMask = 1 - smoothstep(spokeWidth * 0.45, spokeWidth, diff)
			if spokeMask > spokeCanyon then
				spokeCanyon = spokeMask
			end
		end
		local canyonMask = math.max(noiseCanyon * 0.75, spokeCanyon)
		local canyonFloorNoise = math.noise((column.X + pathNoiseX) * 0.06, (column.Z + pathNoiseZ) * 0.06, seed * 0.0021)
		local canyonHeight = config.BaseY + (1 - distance01) * TerrainTuning.CanyonFloorCenterLift + canyonFloorNoise * TerrainTuning.CanyonFloorNoiseAmplitude
		local canyonBlend = math.clamp(canyonMask, 0, 1)
		local wallLift = (1 - canyonBlend) ^ 1.6 * TerrainTuning.MountainWallLift * mountainRing
		local blendedHeight = mountainHeight * (1 - canyonBlend) + canyonHeight * canyonBlend + wallLift
		local edgeDampenT = smoothstep(TerrainTuning.EdgeDampenStart, TerrainTuning.EdgeDampenEnd, distance01)
		if edgeDampenT > 0 then
			local edgeAlpha = edgeDampenT ^ TerrainTuning.EdgeDampenCurve
			local edgeTarget = config.BaseY + TerrainTuning.EdgeDampenHeightOffset
			blendedHeight = blendedHeight * (1 - edgeAlpha) + edgeTarget * edgeAlpha
		end
		local elevation = math.floor(blendedHeight)
		column.SurfaceY = elevation
	end
end

local function chooseBiomeFromClimate(elevationDelta: number, temperature: number, moisture: number, distance01: number): string
	local adjustedMoisture = moisture - smoothstep(0.78, 1.0, distance01) * 0.18
	if elevationDelta >= 34 then
		return "Alpine"
	end
	if elevationDelta >= 20 then
		if adjustedMoisture < -0.2 then
			return "HighlandDesert"
		end
		return "PineHighlands"
	end
	if adjustedMoisture > 0.42 then
		return "Marshland"
	end
	if adjustedMoisture > 0.2 and temperature > -0.28 then
		return "DenseForest"
	end
	if adjustedMoisture > 0.02 then
		return "Forest"
	end
	if temperature > 0.3 and adjustedMoisture < -0.08 then
		return "HighlandDesert"
	end
	return "TemperateGrassland"
end

local function runBiomeSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
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
		local temperatureMacro = math.noise((info.CenterX + temperatureNoiseX) * climateScale, (info.CenterZ + temperatureNoiseZ) * climateScale, seed * 0.00053)
		local temperatureDetail = math.noise((info.CenterX - moistureNoiseZ) * detailScale, (info.CenterZ + moistureNoiseX) * detailScale, seed * 0.00147)
		local moistureMacro = math.noise((info.CenterX + moistureNoiseX) * climateScale, (info.CenterZ + moistureNoiseZ) * climateScale, seed * 0.00063)
		local moistureDetail = math.noise((info.CenterX - temperatureNoiseZ) * detailScale, (info.CenterZ + temperatureNoiseX) * detailScale, seed * 0.00131)
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
		local climateDifference = math.abs(candidate.Temperature - localTemperature) * 0.8 + math.abs(candidate.Moisture - localMoisture) * 1.05
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
		local temperatureMacro = math.noise((column.X + temperatureNoiseX) * climateScale, (column.Z + temperatureNoiseZ) * climateScale, seed * 0.00053)
		local temperatureDetail = math.noise((column.X - moistureNoiseZ) * detailScale, (column.Z + moistureNoiseX) * detailScale, seed * 0.00147)
		local moistureMacro = math.noise((column.X + moistureNoiseX) * climateScale, (column.Z + moistureNoiseZ) * climateScale, seed * 0.00063)
		local moistureDetail = math.noise((column.X - temperatureNoiseZ) * detailScale, (column.Z + temperatureNoiseX) * detailScale, seed * 0.00131)
		local localTemperature = temperatureMacro * 0.74 + temperatureDetail * 0.26
		local localMoisture = moistureMacro * 0.72 + moistureDetail * 0.28 - smoothstep(0.78, 1.0, distance01) * 0.18

		local bestBiome = homeChunk.Biome
		local bestScore = -math.huge
		for dx = -1, 1 do
			for dz = -1, 1 do
				local candidate = chunkInfoByKey[makeColumnKey(chunkX + dx, chunkZ + dz)]
				if candidate then
					local score = scoreChunkBiomeForColumn(column, candidate, homeChunk, localTemperature, localMoisture, edgeDistance)
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

local function runBiomeEdgeSmoothingSieve(columns: { [string]: TileColumn }, config: WorldConfig)
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

local function runThicknessSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	local thicknessNoiseX = (seed % 4337) * 0.13
	local thicknessNoiseZ = (seed % 3911) * 0.09
	local radius = math.max(config.RadiusTiles, 1)
	local depthRng = Random.new(seed + 9917)
	local anchors = {} :: { DepthAnchor }
	local processedCount = 0

	for _ = 1, TerrainTuning.ThicknessAnchorCount do
		local angle = depthRng:NextNumber(0, math.pi * 2)
		local distance = depthRng:NextNumber(radius * 0.18, radius * 0.82)
		local reach = depthRng:NextNumber(radius * TerrainTuning.ThicknessAnchorRadiusMin, radius * TerrainTuning.ThicknessAnchorRadiusMax)
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
		local thicknessNoise = math.noise((column.X + thicknessNoiseX) * 0.15, (column.Z + thicknessNoiseZ) * 0.15, seed * 0.0013)
		local anchorDepth = 0
		for _, anchor in ipairs(anchors) do
			local dx = column.X - anchor.X
			local dz = column.Z - anchor.Z
			local anchorDistance = math.sqrt(dx * dx + dz * dz)
			local influence = 1 - smoothstep(anchor.Radius * TerrainTuning.ThicknessAnchorInnerInfluence, anchor.Radius, anchorDistance)
			local candidateDepth = anchor.Depth * (influence * influence)
			if candidateDepth > anchorDepth then
				anchorDepth = candidateDepth
			end
		end

		local thickness = math.max(TerrainTuning.ThicknessMin, math.floor(
			TerrainTuning.ThicknessBase + centerMass * TerrainTuning.ThicknessCenterScale + thicknessNoise * TerrainTuning.ThicknessNoiseScale + anchorDepth
		))
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

local function runMaterialSieve(columns: { [string]: TileColumn }, _config: WorldConfig)
	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		local materials = getBiomeMaterials(column.Biome)
		column.FillMaterial = materials.Deep
		column.SurfaceMaterial = materials.Surface
	end
end

local function runWaterSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
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

local function chooseWeightedRuntimePrefabId(biome: string, pool: { string }, structureRng: Random): string?
	if #pool == 0 then
		return nil
	end

	local weights = RuntimeStructureWeightsByBiome[biome]
	if not weights or #weights < #pool then
		return pool[structureRng:NextInteger(1, #pool)]
	end

	local totalWeight = 0
	for index = 1, #pool do
		totalWeight += math.max(1, weights[index])
	end
	if totalWeight <= 0 then
		return pool[structureRng:NextInteger(1, #pool)]
	end

	local roll = structureRng:NextNumber(0, totalWeight)
	local cursor = 0
	for index = 1, #pool do
		cursor += math.max(1, weights[index])
		if roll <= cursor then
			return pool[index]
		end
	end

	return pool[#pool]
end

local function runStructureSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	local structureRng = Random.new(seed + 4103)

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		if column.HasWater then
			continue
		end

		local distance = math.sqrt(column.X * column.X + column.Z * column.Z)
		if distance > config.RadiusTiles - 2 then
			continue
		end

		column.StructureTag = nil
		local pool = PrefabRegistry.GetRuntimeNaturePool(column.Biome)
		if #pool == 0 then
			continue
		end

		local chance = RuntimeStructureChanceByBiome[column.Biome] or 0.045
		if structureRng:NextNumber() <= chance then
			column.StructureTag = chooseWeightedRuntimePrefabId(column.Biome, pool, structureRng)
		end
	end
end

local function isMountainBiome(biome: string): boolean
	return biome == "Alpine" or biome == "PineHighlands"
end

local function isForestBiome(biome: string): boolean
	return biome == "Forest" or biome == "DenseForest" or biome == "PineHighlands"
end

local function isPlainsBiome(biome: string): boolean
	return biome == "TemperateGrassland" or biome == "HighlandDesert" or biome == "Marshland"
end

local function runSurfaceSmoothingSieve(columns: { [string]: TileColumn }, config: WorldConfig)
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
			local nextY = math.floor(blendedY + 0.5)

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

local function runPathSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number): (TileColumn?, { TileColumn }, number, { PathRoute })
	local centerColumn = getCenterSolidColumn(columns)
	if not centerColumn then
		return nil, {}, 0, {}
	end

	local endpointCount = math.max(1, TerrainTuning.PathEndpointCount)
	local endpointRng = Random.new(seed + 13127)
	local endpoints = {} :: { TileColumn }
	local allRoutes = {} :: { { PathPoint } }
	local radius = math.max(config.RadiusTiles, 1)
	local sideMinDistanceSq = radius * radius * 0.45
	local startColumn = centerColumn
	local startAngle = endpointRng:NextNumber(0, math.pi * 2)
	local startRadius = radius * endpointRng:NextNumber(TerrainTuning.PathEndpointRadiusMin, TerrainTuning.PathEndpointRadiusMax)
	local startTargetX = math.cos(startAngle) * startRadius
	local startTargetZ = math.sin(startAngle) * startRadius
	local sideStart = getNearestSolidColumnToTarget(columns, startTargetX, startTargetZ, sideMinDistanceSq, centerColumn)
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

	for endpointIndex = 1, endpointCount do
		local angleStep = (math.pi * 2) / endpointCount
		local jitter = endpointRng:NextNumber(-angleStep * 0.2, angleStep * 0.2)
		local endpointAngle = baseAngle + angleStep * (endpointIndex - 1) + jitter
		local endpointRadius = radius * endpointRng:NextNumber(TerrainTuning.PathEndpointRadiusMin, TerrainTuning.PathEndpointRadiusMax)
		local targetX = math.cos(endpointAngle) * endpointRadius
		local targetZ = math.sin(endpointAngle) * endpointRadius
		local endpoint = getNearestSolidColumnToTarget(columns, targetX, targetZ, radius * radius * 0.22, startColumn)
		local isSideEndpoint = endpoint and ((endpoint.X * endpoint.X + endpoint.Z * endpoint.Z) >= sideMinDistanceSq)
		if isSideEndpoint and endpoint and not hasNodeOverlap(usedNodes, endpoint.X, endpoint.Z, TerrainTuning.PathNodeSpacing * 0.8) then
			table.insert(endpoints, endpoint)
			local route = generateWindingPathNodes(columns, startColumn, endpoint, usedNodes, startRadiusScale, seed + endpointIndex * 97)
			if #route >= 2 then
				table.insert(allRoutes, route)
			end
		end
	end

	if #allRoutes == 0 then
		local fallbackEndpoint: TileColumn? = nil
		local bestDistanceSq = -1
		for _, column in pairs(columns) do
			if column.Solid then
				local dx = column.X - startColumn.X
				local dz = column.Z - startColumn.Z
				local distSq = dx * dx + dz * dz
				if distSq > bestDistanceSq then
					bestDistanceSq = distSq
					fallbackEndpoint = column
				end
			end
		end
		if fallbackEndpoint then
			table.insert(endpoints, fallbackEndpoint)
			local fallbackRoute = generateWindingPathNodes(columns, startColumn, fallbackEndpoint, usedNodes, startRadiusScale, seed + 713)
			if #fallbackRoute >= 2 then
				table.insert(allRoutes, fallbackRoute)
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

	local function sampleRingAverageSurfaceY(centerX: number, centerZ: number, innerRadius: number, outerRadius: number): number?
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
		local cityNodeSpacing = math.max(2, TerrainTuning.PathNodeSpacing * math.max(0.5, TerrainTuning.CityNodeSpacingMultiplier))
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
					if not hasNodeOverlap(usedNodes, candidate.X, candidate.Z, cityNodeSpacing) then
						local candidateRadiusScale = cityRng:NextNumber(cityRadiusScaleMin, cityRadiusScaleMax)
						local candidateRadius = math.max(pathHalfWidth, pathHalfWidth * candidateRadiusScale)
						local edgeInner = math.max(1, candidateRadius * TerrainTuning.CityFlattenEdgeInnerRatio)
						local edgeOuter = math.max(edgeInner + 0.5, candidateRadius * TerrainTuning.CityFlattenEdgeOuterRatio)
						local edgeAverage = sampleRingAverageSurfaceY(candidate.X, candidate.Z, edgeInner, edgeOuter)
						local edgeBlend = math.clamp(TerrainTuning.CityFlattenEdgeBlend, 0, 1)
						local flattenedHeight = candidate.SurfaceY
						if edgeAverage then
							flattenedHeight = math.floor(candidate.SurfaceY * (1 - edgeBlend) + edgeAverage * edgeBlend + 0.5)
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

	local function circleTouchesTile(tileX: number, tileZ: number, centerX: number, centerZ: number, radius: number): boolean
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

		local reference = resolveSupportReference(x, z)
		local biome = preferredBiome
		if biome == nil then
			biome = if reference then reference.Biome else config.Biome
		end
		local materials = getBiomeMaterials(biome)

		if not column.Solid then
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

		local surfaceY = math.floor(targetHeight + 0.5)
		if reference then
			local referenceSurface = reference.SurfaceY
			local delta = surfaceY - referenceSurface
			if math.abs(delta) > 12 then
				surfaceY = referenceSurface + math.clamp(delta, -12, 12)
			end
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
		local preferredBiome = if startColumn then startColumn.Biome else if endColumn then endColumn.Biome else config.Biome

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
			local supportRadius = math.max(TerrainTuning.SupportIslandMinRadius, nodeBaseRadius + TerrainTuning.SupportIslandExtraRadius)
			local referenceColumn = resolveSupportReference(node.X, node.Z)
			local preferredBiome = if referenceColumn then referenceColumn.Biome else config.Biome
			local targetHeight = if referenceColumn then math.max(node.Height, referenceColumn.SurfaceY) else node.Height
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
							local blendAlpha = (1 - smoothstep(nodeRadius * 0.2, nodeRadius, localDistance)) * nodeHeightBlendStrength
							local candidateKey = makeColumnKey(candidate.X, candidate.Z)
							if pathCells[candidateKey] == nil then
								pathCells[candidateKey] = node.Height
							else
								pathCells[candidateKey] = pathCells[candidateKey] * (1 - blendAlpha) + node.Height * blendAlpha
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
	local mountainFloorTargets = {} :: { [string]: number }
	local pathTargetHeights = {} :: { [string]: number }
	local mountainFloorSearchRadius = math.max(2, TerrainTuning.MountainPathFloorSearchRadius)
	local mountainFloorOffset = TerrainTuning.MountainPathFloorOffset

	local function estimateMountainFloorTargetY(column: TileColumn): number
		local floorY = column.SurfaceY
		for dx = -mountainFloorSearchRadius, mountainFloorSearchRadius do
			for dz = -mountainFloorSearchRadius, mountainFloorSearchRadius do
				local localDistance = math.sqrt(dx * dx + dz * dz)
				if localDistance > mountainFloorSearchRadius then
					continue
				end
				local neighbor = columns[makeColumnKey(column.X + dx, column.Z + dz)]
				if neighbor and neighbor.Solid then
					local candidate = neighbor.SurfaceY
					if candidate < floorY then
						floorY = candidate
					end
				end
			end
		end

		return floorY + mountainFloorOffset
	end

	for key, baseHeight in pairs(pathCells) do
		local column = columns[key]
		if column and column.Solid then
			local originalSurfaceY = column.SurfaceY
			local flattenNoise = math.noise(
				(column.X + flattenNoiseOffsetX) * 0.08,
				(column.Z + flattenNoiseOffsetZ) * 0.08,
				seed * 0.0027
			) * TerrainTuning.PathFlattenNoiseAmplitude
			local pathTargetY = math.floor(baseHeight + flattenNoise)
			if isMountainBiome(column.Biome) then
				local cachedFloorTarget = mountainFloorTargets[key]
				if cachedFloorTarget == nil then
					cachedFloorTarget = estimateMountainFloorTargetY(column)
					mountainFloorTargets[key] = cachedFloorTarget
				end
				pathTargetY = math.min(pathTargetY, cachedFloorTarget)
			end
			if pathTargetY > originalSurfaceY then
				pathTargetY = originalSurfaceY
			end
			local minPathY = column.BottomY + 2
			if pathTargetY < minPathY then
				pathTargetY = minPathY
			end

			local edgeBlend = math.clamp(TerrainTuning.PathEdgeBlend, 0, 1)
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
					pathTargetY = math.floor(pathTargetY * (1 - edgeBlend) + edgeAverage * edgeBlend + 0.5)
					if pathTargetY > originalSurfaceY then
						pathTargetY = originalSurfaceY
					end
					if pathTargetY < minPathY then
						pathTargetY = minPathY
					end
				end
			end
			pathTargetHeights[key] = pathTargetY
		end
	end

	local mountainSmoothingPasses = math.max(1, TerrainTuning.MountainPathSmoothingPasses)
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
				local smoothed = math.floor(sum / weight + 0.5)
				local floorTarget = mountainFloorTargets[key]
				if floorTarget then
					smoothed = math.min(smoothed, floorTarget)
				end
				if smoothed > column.SurfaceY then
					smoothed = column.SurfaceY
				end
				local minPathY = column.BottomY + 2
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
	local maxNeighborStep = math.max(1, TerrainTuning.PathMaxNeighborStep)
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
				nextY = math.floor(currentTargetY * (1 - continuityAlpha) + average * continuityAlpha + 0.5)
				if minAllowed <= maxAllowed then
					nextY = math.clamp(nextY, minAllowed, maxAllowed)
				end
			end

			local floorTarget = mountainFloorTargets[key]
			if floorTarget then
				nextY = math.min(nextY, floorTarget)
			end
			if nextY > column.SurfaceY then
				nextY = column.SurfaceY
			end
			local minPathY = column.BottomY + 2
			if nextY < minPathY then
				nextY = minPathY
			end
			nextHeights[key] = nextY
		end

		pathTargetHeights = nextHeights
	end

	local nodeFlattenStrength = math.clamp(TerrainTuning.PathNodeFlattenStrength, 0, 1)
	if nodeFlattenStrength > 0 then
		local nodeFlattenRadiusMultiplier = math.max(1, TerrainTuning.PathNodeFlattenRadiusMultiplier)
		local nodeFlattenCore = math.clamp(TerrainTuning.PathNodeFlattenCore, 0, 0.92)
		local nodeInfluence = {} :: { [string]: { SumHeight: number, SumWeight: number } }
		for _, route in ipairs(allRoutes) do
			for _, node in ipairs(route) do
				local nodeRadius = math.max(pathHalfWidth, pathHalfWidth * node.RadiusScale) * nodeFlattenRadiusMultiplier
				local tileRange = math.max(1, math.ceil(nodeRadius + 0.75))
				for dx = -tileRange, tileRange do
					for dz = -tileRange, tileRange do
						local tileX = node.X + dx
						local tileZ = node.Z + dz
						if circleTouchesTile(tileX, tileZ, node.X, node.Z, nodeRadius) then
							local candidateKey = makeColumnKey(tileX, tileZ)
							if pathTargetHeights[candidateKey] ~= nil then
								local localDistance = math.sqrt(dx * dx + dz * dz)
								local influenceAlpha = 1 - smoothstep(nodeRadius * nodeFlattenCore, nodeRadius, localDistance)
								if influenceAlpha > 0 then
									local influence = nodeInfluence[candidateKey]
									if not influence then
										influence = { SumHeight = 0, SumWeight = 0 }
										nodeInfluence[candidateKey] = influence
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

		for key, influence in pairs(nodeInfluence) do
			local column = columns[key]
			local currentTargetY = pathTargetHeights[key]
			if column and column.Solid and currentTargetY and influence.SumWeight > 0 then
				local desiredHeight = influence.SumHeight / influence.SumWeight
				local flattenedY = math.floor(currentTargetY * (1 - nodeFlattenStrength) + desiredHeight * nodeFlattenStrength + 0.5)
				local floorTarget = mountainFloorTargets[key]
				if floorTarget then
					flattenedY = math.min(flattenedY, floorTarget)
				end
				if flattenedY > column.SurfaceY then
					flattenedY = column.SurfaceY
				end
				local minPathY = column.BottomY + 2
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
				if nodeInfluence[key] == nil then
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

				local smoothed = math.floor(sum / weight + 0.5)
				local smoothingBlend = math.min(0.75, nodeFlattenStrength * 0.55)
				local nextY = math.floor(currentTargetY * (1 - smoothingBlend) + smoothed * smoothingBlend + 0.5)
				local floorTarget = mountainFloorTargets[key]
				if floorTarget then
					nextY = math.min(nextY, floorTarget)
				end
				if nextY > column.SurfaceY then
					nextY = column.SurfaceY
				end
				local minPathY = column.BottomY + 2
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
									neighbor.SurfaceY = neighbor.SurfaceY + math.max(1, math.floor(heightDelta * 0.55 + 0.5))
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

	local nodeStructureCount = #NodeStructurePrefabIds
	if nodeStructureCount > 0 then
		local nodeStructureRng = Random.new(seed + 47993)
		local assignedNodeColumns = {} :: { [string]: boolean }
		for _, route in ipairs(allRoutes) do
			if #route == 1 then
				local node = route[1]
				local key = makeColumnKey(node.X, node.Z)
				if not assignedNodeColumns[key] then
					local column = columns[key]
					if column and column.Solid and not column.HasWater and not column.IsPath then
						local prefabIndex = nodeStructureRng:NextInteger(1, nodeStructureCount)
						column.StructureTag = NodeStructurePrefabIds[prefabIndex]
						assignedNodeColumns[key] = true
					end
				end
			end
		end
	end

	-- Bridge structure tags are intentionally disabled for prefab-only runtime scenery.

	return startColumn, endpoints, #usedNodes, allRoutes
end

local function serializeColumn(column: TileColumn): TileColumnPayload
	return {
		X = column.X,
		Z = column.Z,
		Solid = column.Solid,
		Biome = column.Biome,
		IsPath = column.IsPath,
		SurfaceY = column.SurfaceY,
		BottomY = column.BottomY,
		SurfaceMaterial = column.SurfaceMaterial.Name,
		PathMaterial = if column.PathMaterial then column.PathMaterial.Name else nil,
		FillMaterial = column.FillMaterial.Name,
		HasWater = column.HasWater,
		StructureTag = column.StructureTag,
	}
end

local function buildChunkPayloads(columns: { [string]: TileColumn }, config: WorldConfig): { ChunkData }
	local chunkMap = {} :: { [string]: { ChunkX: number, ChunkZ: number, Columns: { TileColumnPayload } } }

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		local chunkX = math.floor(column.X / config.ChunkSize)
		local chunkZ = math.floor(column.Z / config.ChunkSize)
		local key = makeColumnKey(chunkX, chunkZ)
		local chunk = chunkMap[key]
		if not chunk then
			chunk = {
				ChunkX = chunkX,
				ChunkZ = chunkZ,
				Columns = {},
			}
			chunkMap[key] = chunk
		end

		table.insert(chunk.Columns, serializeColumn(column))
	end

	local chunks = {} :: { ChunkData }
	for _, chunk in pairs(chunkMap) do
		table.sort(chunk.Columns, function(a: TileColumnPayload, b: TileColumnPayload)
			if a.Z == b.Z then
				return a.X < b.X
			end
			return a.Z < b.Z
		end)
		table.insert(chunks, {
			ChunkX = chunk.ChunkX,
			ChunkZ = chunk.ChunkZ,
			Columns = chunk.Columns,
		})
	end

	table.sort(chunks, function(a: ChunkData, b: ChunkData)
		if a.ChunkZ == b.ChunkZ then
			return a.ChunkX < b.ChunkX
		end
		return a.ChunkZ < b.ChunkZ
	end)

	return chunks
end

local function buildChunkLookup(chunks: { ChunkData }): { [string]: ChunkData }
	local lookup = {} :: { [string]: ChunkData }
	for _, chunk in ipairs(chunks) do
		lookup[makeColumnKey(chunk.ChunkX, chunk.ChunkZ)] = chunk
	end
	return lookup
end

local function collectNearestChunks(chunks: { ChunkData }, centerChunkX: number, centerChunkZ: number, maxCount: number): { ChunkData }
	local ranked = {} :: { ChunkDistance }
	for _, chunk in ipairs(chunks) do
		local dx = chunk.ChunkX - centerChunkX
		local dz = chunk.ChunkZ - centerChunkZ
		table.insert(ranked, {
			Chunk = chunk,
			DistanceSq = dx * dx + dz * dz,
		})
	end

	table.sort(ranked, function(a: ChunkDistance, b: ChunkDistance): boolean
		return a.DistanceSq < b.DistanceSq
	end)

	local nearest = {} :: { ChunkData }
	local limit = math.min(math.max(0, maxCount), #ranked)
	for index = 1, limit do
		table.insert(nearest, ranked[index].Chunk)
	end
	return nearest
end

local function createCollisionPart(
	parent: Instance,
	name: string,
	xTileMin: number,
	xTileMax: number,
	zTileMin: number,
	zTileMax: number,
	topY: number,
	bottomY: number,
	tileSize: number
): Part
	local sizeX = (xTileMax - xTileMin + 1) * tileSize
	local sizeZ = (zTileMax - zTileMin + 1) * tileSize
	local sizeY = math.max(1, topY - bottomY + 1)

	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = false
	part.Material = Enum.Material.Slate
	part.Color = Color3.fromRGB(90, 90, 100)
	part.Transparency = 1
	part.Size = Vector3.new(sizeX, sizeY, sizeZ)
	part.Position = Vector3.new((xTileMin + xTileMax) * 0.5 * tileSize, (bottomY + topY) * 0.5, (zTileMin + zTileMax) * 0.5 * tileSize)
	part.Parent = parent
	return part
end

local function bakeCollision(chunks: { ChunkData }, config: WorldConfig): number
	if not CollisionRoot then
		return 0
	end

	local totalParts = 0
	for _, chunk in ipairs(chunks) do
		local chunkFolder = Instance.new("Folder")
		chunkFolder.Name = string.format("Chunk_%d_%d", chunk.ChunkX, chunk.ChunkZ)
		chunkFolder.Parent = CollisionRoot

		local rows = {} :: { [number]: { { X: number, SurfaceY: number, BottomY: number } } }
		for _, payload in ipairs(chunk.Columns) do
			if not payload.Solid then
				continue
			end

			rows[payload.Z] = rows[payload.Z] or {}
			table.insert(rows[payload.Z], {
				X = payload.X,
				SurfaceY = payload.SurfaceY,
				BottomY = payload.BottomY,
			})
		end

		local active = {} :: { [string]: { XMin: number, XMax: number, ZMin: number, ZMax: number, SurfaceY: number, BottomY: number } }
		local sortedZ = {}
		for rowZ in pairs(rows) do
			table.insert(sortedZ, rowZ)
		end
		table.sort(sortedZ)

		for _, rowZ in ipairs(sortedZ) do
			local row = rows[rowZ]
			table.sort(row, function(a, b)
				return a.X < b.X
			end)

			local nextActive = {} :: { [string]: { XMin: number, XMax: number, ZMin: number, ZMax: number, SurfaceY: number, BottomY: number } }
			local index = 1
			while index <= #row do
				local start = row[index]
				local xMin = start.X
				local xMax = start.X
				local topY = start.SurfaceY
				local bottomY = start.BottomY

				local nextIndex = index + 1
				while nextIndex <= #row do
					local candidate = row[nextIndex]
					if candidate.X ~= xMax + 1 or candidate.SurfaceY ~= topY or candidate.BottomY ~= bottomY then
						break
					end

					xMax = candidate.X
					nextIndex += 1
				end

				local key = string.format("%d:%d:%d:%d", xMin, xMax, topY, bottomY)
				local continuing = active[key]
				if continuing and continuing.ZMax == rowZ - 1 then
					continuing.ZMax = rowZ
					nextActive[key] = continuing
				else
					nextActive[key] = {
						XMin = xMin,
						XMax = xMax,
						ZMin = rowZ,
						ZMax = rowZ,
						SurfaceY = topY,
						BottomY = bottomY,
					}
				end

				index = nextIndex
			end

			for key, prism in pairs(active) do
				if not nextActive[key] then
					local tileSize = config.TileSize
					createCollisionPart(
						chunkFolder,
						"Collision",
						prism.XMin,
						prism.XMax,
						prism.ZMin,
						prism.ZMax,
						prism.SurfaceY,
						prism.BottomY,
						tileSize
					)
					totalParts += 1
				end
			end

			active = nextActive
		end

		for _, prism in pairs(active) do
			local tileSize = config.TileSize
			createCollisionPart(
				chunkFolder,
				"Collision",
				prism.XMin,
				prism.XMax,
				prism.ZMin,
				prism.ZMax,
				prism.SurfaceY,
				prism.BottomY,
				tileSize
			)
			totalParts += 1
		end
	end

	return totalParts
end

local function generateWorld(seed: number): WorldState
	local config = makeDefaultConfig(seed)
	local columns = createEmptyColumns(config)

	runFootprintSieve(columns, config, seed)
	runHeightSieve(columns, config, seed)
	runBiomeSieve(columns, config, seed)
	runBiomeEdgeSmoothingSieve(columns, config)
	runSurfaceSmoothingSieve(columns, config)
	runThicknessSieve(columns, config, seed)
	runMaterialSieve(columns, config)
	runWaterSieve(columns, config, seed)
	runStructureSieve(columns, config, seed)
	local pathStart, pathEndpoints, pathNodeCount, pathRoutes = runPathSieve(columns, config, seed)

	local chunks = buildChunkPayloads(columns, config)
	local chunkLookup = buildChunkLookup(chunks)
	clearCollisionRoot()
	local collisionParts = bakeCollision(chunks, config)

	return {
		Seed = seed,
		Config = config,
		Columns = columns,
		Chunks = chunks,
		ChunkLookup = chunkLookup,
		CollisionParts = collisionParts,
		PathStart = pathStart,
		PathEndpoints = pathEndpoints,
		PathNodeCount = pathNodeCount,
		PathRoutes = pathRoutes,
	}
end

local function fireWorldToPlayer(player: Player)
	if not CurrentWorld then
		return
	end

	local spawnColumn = getPreferredSpawnColumn(CurrentWorld)
	local spawnChunkX = 0
	local spawnChunkZ = 0
	if spawnColumn then
		spawnChunkX = math.floor(spawnColumn.X / CurrentWorld.Config.ChunkSize)
		spawnChunkZ = math.floor(spawnColumn.Z / CurrentWorld.Config.ChunkSize)
	end

	API:FireClient(player, "ClearWorld", {})
	API:FireClient(player, "InitializeWorld", {
		Seed = CurrentWorld.Seed,
		Config = CurrentWorld.Config,
		ChunkCount = #CurrentWorld.Chunks,
		SpawnChunkX = spawnChunkX,
		SpawnChunkZ = spawnChunkZ,
		StreamRadius = StreamingTuning.SuggestedStreamRadius,
		UnloadRadius = StreamingTuning.SuggestedUnloadRadius,
		PathRoutes = CurrentWorld.PathRoutes,
	})

	local burstCount = math.max(1, StreamingTuning.InitialChunkBurst)
	local burstChunks = collectNearestChunks(CurrentWorld.Chunks, spawnChunkX, spawnChunkZ, burstCount)
	for _, chunk in ipairs(burstChunks) do
		API:FireClient(player, "LoadChunk", chunk)
	end

	teleportPlayerToSpawn(player)
end

local function broadcastWorld()
	for _, player in ipairs(Players:GetPlayers()) do
		fireWorldToPlayer(player)
	end
end

local function sendRequestedChunksToPlayer(player: Player, payload: { [string]: any }?)
	if not CurrentWorld or not payload then
		return
	end

	local requestList = payload.Chunks
	if type(requestList) ~= "table" then
		local singleChunkX = payload.ChunkX
		local singleChunkZ = payload.ChunkZ
		if type(singleChunkX) == "number" and type(singleChunkZ) == "number" then
			local chunkX = math.floor(singleChunkX)
			local chunkZ = math.floor(singleChunkZ)
			local singleChunk = CurrentWorld.ChunkLookup[makeColumnKey(chunkX, chunkZ)]
			if singleChunk then
				API:FireClient(player, "LoadChunk", singleChunk)
			end
		end
		return
	end

	local maxRequests = math.max(1, StreamingTuning.MaxChunkRequestsPerMessage)
	local limit = math.min(#requestList, maxRequests)
	for index = 1, limit do
		local request = requestList[index]
		if type(request) == "table" then
			local rawChunkX = request.ChunkX
			local rawChunkZ = request.ChunkZ
			if type(rawChunkX) == "number" and type(rawChunkZ) == "number" then
				local chunkX = math.floor(rawChunkX)
				local chunkZ = math.floor(rawChunkZ)
				local chunk = CurrentWorld.ChunkLookup[makeColumnKey(chunkX, chunkZ)]
				if chunk then
					API:FireClient(player, "LoadChunk", chunk)
				end
			end
		end
	end
end

function WorldServiceServer.GetSeed(): number
	return CurrentSeed
end

function WorldServiceServer.GetWorld(): WorldState?
	return CurrentWorld
end

function WorldServiceServer.GetTile(x: number, z: number): TileColumn?
	if not CurrentWorld then
		return nil
	end

	return CurrentWorld.Columns[makeColumnKey(math.floor(x), math.floor(z))]
end

function WorldServiceServer.Regenerate(seedOverride: number?): number
	local seed = if type(seedOverride) == "number" then math.max(1, math.floor(seedOverride)) else deriveServerSeed()
	CurrentSeed = seed
	CurrentWorld = generateWorld(seed)

	if WorldRoot then
		WorldRoot:SetAttribute("WorldSeed", seed)
		WorldRoot:SetAttribute("WorldBiome", CurrentWorld.Config.Biome)
		WorldRoot:SetAttribute("WorldRadiusTiles", CurrentWorld.Config.RadiusTiles)
		WorldRoot:SetAttribute("CollisionPartCount", CurrentWorld.CollisionParts)
		WorldRoot:SetAttribute("PathEndpointCount", #CurrentWorld.PathEndpoints)
		WorldRoot:SetAttribute("PathNodeCount", CurrentWorld.PathNodeCount)
	end
	updateDebugHarness(CurrentWorld)
	updateSpawnLocation(CurrentWorld)

	print(string.format(
		"[WorldService] Generated floating island seed=%d chunks=%d collisionParts=%d pathEndpoints=%d pathNodes=%d",
		seed,
		if CurrentWorld then #CurrentWorld.Chunks else 0,
		if CurrentWorld then CurrentWorld.CollisionParts else 0,
		if CurrentWorld then #CurrentWorld.PathEndpoints else 0,
		if CurrentWorld then CurrentWorld.PathNodeCount else 0
	))

	broadcastWorld()
	return seed
end

function WorldServiceServer.init()
	ensureWorldRoots()
	local initialSeed = deriveServerSeed()
	WorldServiceServer.Regenerate(initialSeed)
end

Players.PlayerAdded:Connect(function(player)
	if ActiveSpawnLocation then
		player.RespawnLocation = ActiveSpawnLocation
	end

	if CurrentWorld then
		fireWorldToPlayer(player)
	end
end)

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "RequestWorld" then
		fireWorldToPlayer(player)
	elseif action == "RequestChunks" then
		sendRequestedChunksToPlayer(player, payload)
	elseif action == "RequestRegenerate" then
		if RunService:IsStudio() then
			local override = payload and payload.Seed
			WorldServiceServer.Regenerate(if type(override) == "number" then override else nil)
		end
	end
end)

return table.freeze(WorldServiceServer)
