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
local PrefabExecutor = require(script.Parent.Prefabs.PrefabExecutor)
local WorldStructureSettings = require(script.Parent.WorldStructureSettings)
local WorldSpawnServiceServer = require(script.Parent.WorldSpawnServiceServer)
local FootprintSieve = require(script.Parent.Sieves.FootprintSieve)
local HeightSieve = require(script.Parent.Sieves.HeightSieve)
local BiomeSieve = require(script.Parent.Sieves.BiomeSieve)
local BiomeEdgeSmoothingSieve = require(script.Parent.Sieves.BiomeEdgeSmoothingSieve)
local ThicknessSieve = require(script.Parent.Sieves.ThicknessSieve)
local MaterialSieve = require(script.Parent.Sieves.MaterialSieve)
local WaterSieve = require(script.Parent.Sieves.WaterSieve)
local StructureSieve = require(script.Parent.Sieves.StructureSieve)
local SurfaceSmoothingSieve = require(script.Parent.Sieves.SurfaceSmoothingSieve)
local PathSieve = require(script.Parent.Sieves.PathSieve)
local StructureFootprintFlatteningSieve = require(script.Parent.Sieves.StructureFootprintFlatteningSieve)
local HeightSnapSieve = require(script.Parent.Sieves.HeightSnapSieve)


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
	PathRoutes: { { {
		X: number,
		Z: number,
		Height: number,
		RadiusScale: number,
		IsStructureNode: boolean?,
		PathRadiusTiles: number?,
		FlattenRadiusTiles: number?,
	} } },
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
	IsStructureNode: boolean?,
	PathRadiusTiles: number?,
	FlattenRadiusTiles: number?,
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
	HeightSnapStep = 0.5,
	PathEndpointCount = 2,
	PathEndpointRadiusMin = 0.72,
	PathEndpointRadiusMax = 0.92,
	PathWanderStrength = 1.75,
	PathWanderSecondaryStrength = 1.05,
	PathWanderForwardStrength = 0.72,
	PathStepTiles = 1,
	PathHalfWidth = 2.8,
	PathShoulderWidth = 6.5,
	PathMountainCliffRise = 2.5,
	PathForestClearingWidth = 2.6,
	PathFlattenNoiseAmplitude = 0,
	MountainBridgeChance = 0.08,
	MountainBridgeMinGapDrop = 4,
	MountainBridgeMinSpacing = 8,
	PathNodeHeightBlendStrength = 0.9,
	PathNodeFlattenStrength = 1,
	PathNodeFlattenRadiusMultiplier = 3.1,
	PathNodeFlattenCore = 0.08,
	PathNodeFlattenSmoothingPasses = 3,
	PathNodeFlattenMinimumRadiusTiles = 7.5,
	PathNodeFlattenHardRadiusRatio = 0.62,
	PathNodeFlattenEdgeFloorInfluence = 0.32,
	PathNodeFlattenSeparationFactor = 0.45,
	PathNodeSpacing = 14,
	PathNodeMinSpacing = 22,
	PathNodeFlattenMaxCutDepth = 64,
	PathNodeSearchRadius = 5,
	PathNodePlacementAttempts = 14,
	PathNodeLateralJitter = 14.5,
	PathNodeSegmentLength = 22,
	PathNodeRadiusScaleMin = 1,
	PathNodeRadiusScaleMax = 2,
	PathNodeTargetGoalBlend = 0.72,
	PathNodeTargetLocalBlend = 0.4,
	PathNodeRisePerTile = 0.18,
	PathNodeFallPerTile = 0.22,
	PathNodeHeightJitter = 0.12,
	PathNodeHeightSmoothingPasses = 4,
	PathNodeHeightSmoothingBlend = 0.62,
	PathNodeMaxRouteHeightDelta = 0,
	PathAggressiveFlattenPasses = 2,
	PathAggressiveFlattenBlend = 0.88,
	PathMaxHeightRange = 2.5,
	PathNonMountainPreserveAlpha = 0.4,
	PathNonMountainMaxCutDepth = 3,
	PathNonMountainSmoothingPasses = 3,
	PathNonMountainSmoothingBlend = 0.72,
	PathNodeStructureChance = 0.34,
	AmbientStructureNodeCount = 18,
	AmbientStructureNodeAttempts = 260,
	AmbientStructureNodeMinSpacing = 16,
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
	BiomeChunkTileSpan = 52,
	BiomeChunkJitter = 0.34,
	BiomeChunkBlendWidth = 13,
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
	PathMaxNeighborStep = 0.5,
	MountainPathFloorSearchRadius = 6,
	MountainPathFloorOffset = 1,
	MountainPathSmoothingPasses = 0,
	SupportSearchRadius = 10,
	SupportIslandMinRadius = 3.8,
	SupportIslandExtraRadius = 2.9,
	SupportIslandThickness = 62,
	SupportMaxRiseFromReference = 3,
	SupportBridgeHalfWidth = 2.8,
	SupportBridgeThickness = 58,
	SupportBridgeEdgeDrop = 3.2,
	EdgeDampenStart = 0.65,
	EdgeDampenEnd = 0.98,
	EdgeDampenCurve = 2.2,
	EdgeDampenHeightOffset = 1.0,
}

local StreamingTuning = {
	InitialChunkBurst = 24,
	MaxChunkRequestsPerMessage = 18,
	SuggestedStreamRadius = 8,
	SuggestedUnloadRadius = 11,
}

-- Keep this aligned with PrefabUtils structure scaling.
local STRUCTURE_PREFAB_SCALE = 1.3
local HABITATION_STRUCTURE_SCALE = 1.58
local ENVIRONMENT_STRUCTURE_SCALE = 1.42

local RuntimeNatureChanceByBiome: { [string]: number } = WorldStructureSettings.RuntimeNatureChanceByBiome
local RuntimeNatureWeightsByBiome: { [string]: { number } } = WorldStructureSettings.RuntimeNatureWeightsByBiome
local RuntimeNodeStructuresEnabled = WorldStructureSettings.RuntimeNodeStructuresEnabled
local RuntimeNodeStructureChance = math.clamp(
	if type(WorldStructureSettings.RuntimeNodeStructureChance) == "number"
		then WorldStructureSettings.RuntimeNodeStructureChance
		else TerrainTuning.PathNodeStructureChance,
	0,
	1
)
local RuntimeNodePoolByBiome: { [string]: { string } } = WorldStructureSettings.RuntimeNodePoolByBiome
local RuntimeNodeWeightsByBiome: { [string]: { number } } = WorldStructureSettings.RuntimeNodeWeightsByBiome
local RuntimeNodeSharedPool: { string } = WorldStructureSettings.RuntimeNodeSharedPool
local RuntimeNodeSharedWeights: { number } = WorldStructureSettings.RuntimeNodeSharedWeights
local RuntimeNodeAssemblyPlacement = WorldStructureSettings.RuntimeNodeAssemblyPlacement
local RuntimeNodeAssemblyDefinitions = WorldStructureSettings.RuntimeNodeAssemblyDefinitions
local RuntimeNodeAssemblyPoolByBiome: { [string]: { string } } = WorldStructureSettings.RuntimeNodeAssemblyPoolByBiome
local RuntimeNodeAssemblyWeightsByBiome: { [string]: { number } } =
	WorldStructureSettings.RuntimeNodeAssemblyWeightsByBiome
local RuntimeNodeAssemblySharedPool: { string } = WorldStructureSettings.RuntimeNodeAssemblySharedPool
local RuntimeNodeAssemblySharedWeights: { number } = WorldStructureSettings.RuntimeNodeAssemblySharedWeights
local ManualStructurePreviewSettings = WorldStructureSettings.ManualStructurePreview
local StructureFlatteningSettings = WorldStructureSettings.StructureFlattening

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
		local origin = world.PathStart
		local bestNearStart: TileColumn? = nil
		local bestNearStartScore = -math.huge
		for dx = -4, 4 do
			for dz = -4, 4 do
				local candidate = world.Columns[makeColumnKey(origin.X + dx, origin.Z + dz)]
				if candidate and candidate.Solid and not candidate.HasWater then
					local slopePenalty = 0
					local neighborCount = 0
					for _, offset in ipairs({
						{ 1, 0 },
						{ -1, 0 },
						{ 0, 1 },
						{ 0, -1 },
					}) do
						local neighbor = world.Columns[makeColumnKey(candidate.X + offset[1], candidate.Z + offset[2])]
						if neighbor and neighbor.Solid then
							slopePenalty += math.abs(neighbor.SurfaceY - candidate.SurfaceY)
							neighborCount += 1
						end
					end
					local avgSlope = if neighborCount > 0 then slopePenalty / neighborCount else 99
					local flatScore = 1 - math.clamp(avgSlope / 3, 0, 1)
					local dist = math.sqrt(dx * dx + dz * dz)
					local distScore = 1 - math.clamp(dist / 4, 0, 1)
					local score = flatScore * 1.5 + distScore
					if score > bestNearStartScore then
						bestNearStartScore = score
						bestNearStart = candidate
					end
				end
			end
		end
		if bestNearStart then
			return bestNearStart
		end
		return origin
	end

	local best: TileColumn? = nil
	local bestScore = -math.huge
	local config = world.Config
	local favoredBiomes = {
		TemperateGrassland = 1.35,
		Forest = 1.2,
		HighlandDesert = 1.15,
	}

	for _, column in pairs(world.Columns) do
		if not column.Solid or column.HasWater then
			continue
		end

		local distanceSq = column.X * column.X + column.Z * column.Z
		local centerFalloff = 1 - math.clamp(math.sqrt(distanceSq) / math.max(1, config.RadiusTiles), 0, 1)

		local slopePenalty = 0
		local neighborCount = 0
		for _, offset in ipairs({
			{ 1, 0 },
			{ -1, 0 },
			{ 0, 1 },
			{ 0, -1 },
			{ 1, 1 },
			{ -1, 1 },
			{ 1, -1 },
			{ -1, -1 },
		}) do
			local neighbor = world.Columns[makeColumnKey(column.X + offset[1], column.Z + offset[2])]
			if neighbor and neighbor.Solid then
				slopePenalty += math.abs(neighbor.SurfaceY - column.SurfaceY)
				neighborCount += 1
			end
		end
		local averageSlope = if neighborCount > 0 then slopePenalty / neighborCount else 99
		local flatnessScore = 1 - math.clamp(averageSlope / 3, 0, 1)
		local elevationDelta = math.abs(column.SurfaceY - config.BaseY)
		local elevationScore = 1 - math.clamp(elevationDelta / 20, 0, 1)
		local biomeWeight = favoredBiomes[column.Biome] or 1

		local score = (centerFalloff * 0.95 + flatnessScore * 1.8 + elevationScore * 1.35) * biomeWeight
		if score > bestScore then
			bestScore = score
			best = column
		end
	end

	if best then
		return best
	end

	local fallback: TileColumn? = nil
	local fallbackDistanceSq = math.huge
	for _, column in pairs(world.Columns) do
		if column.Solid then
			local distanceSq = column.X * column.X + column.Z * column.Z
			if distanceSq < fallbackDistanceSq then
				fallbackDistanceSq = distanceSq
				fallback = column
			end
		end
	end
	return fallback
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

local function spawnManualStructurePreview(world: WorldState)
	if not ManualStructurePreviewSettings.Enabled then
		return
	end
	if ManualStructurePreviewSettings.StudioOnly and not RunService:IsStudio() then
		return
	end

	local gridOffset = ManualStructurePreviewSettings.GridOffsetStuds
	local heightOffset = ManualStructurePreviewSettings.HeightOffsetStuds
	local basePosition = Vector3.new(0, world.Config.BaseY + heightOffset, 0)
	if ActiveSpawnLocation then
		basePosition = ActiveSpawnLocation.Position + Vector3.new(gridOffset, heightOffset, gridOffset)
	end

	local ok, result = pcall(function()
		return PrefabExecutor.GenerateGallery({
			ClearExisting = true,
			IncludeExecutorOnly = ManualStructurePreviewSettings.IncludeExecutorOnly,
			IncludeNature = ManualStructurePreviewSettings.IncludeNature,
			IncludeStructures = ManualStructurePreviewSettings.IncludeStructures,
			IncludeMarkers = ManualStructurePreviewSettings.IncludeMarkers,
			TileSize = ManualStructurePreviewSettings.TileSize,
			SpacingStuds = ManualStructurePreviewSettings.SpacingStuds,
			BasePosition = basePosition,
		})
	end)
	if not ok then
		warn(string.format("[WorldService] Failed to spawn manual structure preview: %s", tostring(result)))
		return
	end

	local galleryRoot = result :: Folder
	galleryRoot:SetAttribute("WorldSeed", world.Seed)
	galleryRoot:SetAttribute("GeneratedBy", "PrefabExecutor")
end

local function teleportPlayerToSpawn(player: Player, attemptsRemaining: number?)
	if not ActiveSpawnLocation then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		local retries = if attemptsRemaining ~= nil then attemptsRemaining else 20
		if retries > 0 then
			task.delay(0.15, function()
				if player.Parent and character.Parent then
					teleportPlayerToSpawn(player, retries - 1)
				end
			end)
		end
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

local function snapHeight(value: number): number
	local step = math.max(0.01, TerrainTuning.HeightSnapStep)
	return math.floor(value / step + 0.5) * step
end

local function angularDistance(a: number, b: number): number
	return math.abs(math.atan2(math.sin(a - b), math.cos(a - b)))
end

local function getSolidColumnNear(
	columns: { [string]: TileColumn },
	x: number,
	z: number,
	maxRadius: number
): TileColumn?
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

local function getPathNodeBaseRadiusTiles(radiusScale: number?): number
	local resolvedScale = if radiusScale and radiusScale > 0 then radiusScale else 1
	local pathHalfWidth = math.max(0.5, TerrainTuning.PathHalfWidth)
	return math.max(pathHalfWidth, pathHalfWidth * resolvedScale)
end

local function getPathNodeFlattenRadiusTiles(radiusScale: number?): number
	local baseRadius = getPathNodeBaseRadiusTiles(radiusScale)
	local multiplier = math.max(1, TerrainTuning.PathNodeFlattenRadiusMultiplier)
	local minFlattenRadius = math.max(baseRadius, TerrainTuning.PathNodeFlattenMinimumRadiusTiles)
	return math.max(minFlattenRadius, baseRadius * multiplier)
end

local function hasNodeOverlap(
	nodes: { PathPoint },
	x: number,
	z: number,
	minSpacing: number,
	candidateRadiusScale: number?
): boolean
	local minSpacingSq = minSpacing * minSpacing
	local separationFactor = math.clamp(TerrainTuning.PathNodeFlattenSeparationFactor, 0, 1)
	local candidateFlattenRadius = getPathNodeFlattenRadiusTiles(candidateRadiusScale)
	for _, node in ipairs(nodes) do
		local dx = node.X - x
		local dz = node.Z - z
		local distanceSq = dx * dx + dz * dz
		if distanceSq <= minSpacingSq then
			return true
		end

		if separationFactor > 0 then
			local otherFlattenRadius = getPathNodeFlattenRadiusTiles(node.RadiusScale)
			local minSeparation = (candidateFlattenRadius + otherFlattenRadius) * separationFactor
			if distanceSq <= (minSeparation * minSeparation) then
				return true
			end
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
	local minSpacing = math.max(TerrainTuning.PathNodeSpacing, TerrainTuning.PathNodeMinSpacing)

	for _ = 1, attempts do
		local candidateX = desiredX + rng:NextNumber(-jitter, jitter)
		local candidateZ = desiredZ + rng:NextNumber(-jitter, jitter)
		local candidateRadiusScale = randomNodeRadiusScale(rng)
		local snappedColumn =
			getSolidColumnNear(columns, math.floor(candidateX + 0.5), math.floor(candidateZ + 0.5), searchRadius)
		if
			snappedColumn
			and not hasNodeOverlap(usedNodes, snappedColumn.X, snappedColumn.Z, minSpacing, candidateRadiusScale)
		then
			return {
				X = snappedColumn.X,
				Z = snappedColumn.Z,
				Height = snappedColumn.SurfaceY,
				RadiusScale = candidateRadiusScale,
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
	local maxRouteDelta = math.max(0, TerrainTuning.PathNodeMaxRouteHeightDelta)
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

	local rawStartHeight = clampNodeHeightToColumn(columns, route[1], route[1].Height)
	local rawEndHeight = clampNodeHeightToColumn(columns, route[nodeCount], route[nodeCount].Height)
	local routeReferenceHeight = (rawStartHeight + rawEndHeight) * 0.5
	local minRouteHeight = routeReferenceHeight - maxRouteDelta
	local maxRouteHeight = routeReferenceHeight + maxRouteDelta
	local function clampToRouteBand(node: PathPoint, value: number): number
		local bandedValue = value
		if maxRouteDelta > 0 then
			bandedValue = math.clamp(bandedValue, minRouteHeight, maxRouteHeight)
		end
		return clampNodeHeightToColumn(columns, node, bandedValue)
	end
	local startHeight = clampToRouteBand(route[1], rawStartHeight)
	local endHeight = clampToRouteBand(route[nodeCount], rawEndHeight)
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
		targetHeights[nodeIndex] = clampToRouteBand(node, targetHeight)
	end

	local function applySlopeConstraints()
		for nodeIndex = 2, nodeCount do
			local previousHeight = targetHeights[nodeIndex - 1]
			local currentHeight = targetHeights[nodeIndex]
			local segmentDistance = math.max(1, cumulativeDistance[nodeIndex] - cumulativeDistance[nodeIndex - 1])
			local minAllowed = previousHeight - fallPerTile * segmentDistance
			local maxAllowed = previousHeight + risePerTile * segmentDistance
			targetHeights[nodeIndex] = clampToRouteBand(route[nodeIndex], math.clamp(currentHeight, minAllowed, maxAllowed))
		end

		for nodeIndex = nodeCount - 1, 2, -1 do
			local nextHeight = targetHeights[nodeIndex + 1]
			local currentHeight = targetHeights[nodeIndex]
			local segmentDistance = math.max(1, cumulativeDistance[nodeIndex + 1] - cumulativeDistance[nodeIndex])
			local minAllowed = nextHeight - risePerTile * segmentDistance
			local maxAllowed = nextHeight + fallPerTile * segmentDistance
			targetHeights[nodeIndex] = clampToRouteBand(route[nodeIndex], math.clamp(currentHeight, minAllowed, maxAllowed))
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
			nextHeights[nodeIndex] = clampToRouteBand(route[nodeIndex], smoothedHeight)
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
	local structureChance = RuntimeNodeStructureChance
	local minSpacing = math.max(TerrainTuning.PathNodeSpacing, TerrainTuning.PathNodeMinSpacing)
	local route = {} :: { PathPoint }
	local startNode = {
		X = startColumn.X,
		Z = startColumn.Z,
		Height = startColumn.SurfaceY,
		RadiusScale = startRadiusScale,
		IsStructureNode = false,
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
			placed.IsStructureNode = rng:NextNumber() < structureChance
			table.insert(route, placed)
			table.insert(usedNodes, placed)
		end
	end

	local endNodeCandidate = tryPlaceNode(columns, usedNodes, rng, endColumn.X, endColumn.Z)
	local endNode = if endNodeCandidate
		then endNodeCandidate
		else {
			X = endColumn.X,
			Z = endColumn.Z,
			Height = endColumn.SurfaceY,
			RadiusScale = randomNodeRadiusScale(rng),
			IsStructureNode = false,
		}
	endNode.IsStructureNode = false
	if not endNodeCandidate and hasNodeOverlap(usedNodes, endNode.X, endNode.Z, minSpacing, endNode.RadiusScale) then
		local fallbackColumn =
			getSolidColumnNear(columns, endColumn.X, endColumn.Z, TerrainTuning.PathNodeSearchRadius + 2)
		if
			fallbackColumn
			and not hasNodeOverlap(usedNodes, fallbackColumn.X, fallbackColumn.Z, minSpacing, endNode.RadiusScale)
		then
			endNode = {
				X = fallbackColumn.X,
				Z = fallbackColumn.Z,
				Height = fallbackColumn.SurfaceY,
				RadiusScale = randomNodeRadiusScale(rng),
				IsStructureNode = false,
			}
		end
	end
	local canPlaceEndNode = not hasNodeOverlap(usedNodes, endNode.X, endNode.Z, minSpacing, endNode.RadiusScale)
	if canPlaceEndNode then
		table.insert(usedNodes, endNode)
		table.insert(route, endNode)
	end

	applyGradualRouteNodeHeights(columns, route, seed + 17)

	return route
end

local function runFootprintSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	FootprintSieve({
		rotate2D = rotate2D,
	}, columns, config, seed)
end

local function runHeightSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	HeightSieve({
		smoothstep = smoothstep,
		snapHeight = snapHeight,
		angularDistance = angularDistance,
		TerrainTuning = TerrainTuning,
	}, columns, config, seed)
end


local function runBiomeSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	BiomeSieve({
		makeColumnKey = makeColumnKey,
		smoothstep = smoothstep,
		TerrainTuning = TerrainTuning,
	}, columns, config, seed)
end


local function runBiomeEdgeSmoothingSieve(columns: { [string]: TileColumn }, config: WorldConfig)
	BiomeEdgeSmoothingSieve({
		makeColumnKey = makeColumnKey,
		smoothstep = smoothstep,
		TerrainTuning = TerrainTuning,
	}, columns, config, nil)
end

local function runThicknessSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	ThicknessSieve({
		makeColumnKey = makeColumnKey,
		smoothstep = smoothstep,
		TerrainTuning = TerrainTuning,
	}, columns, config, seed)
end

local function runMaterialSieve(columns: { [string]: TileColumn }, _config: WorldConfig)
	MaterialSieve({
		getBiomeMaterials = getBiomeMaterials,
	}, columns, _config, nil)
end

local function runWaterSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	WaterSieve({
		getBiomeMaterials = getBiomeMaterials,
	}, columns, config, seed)
end

local function chooseWeightedRuntimePrefabId(pool: { string }, weights: { number }?, structureRng: Random): string?
	if #pool == 0 then
		return nil
	end

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

local function getRuntimeNodePool(biome: string): ({ string }, { number }?)
	local biomePool = RuntimeNodePoolByBiome[biome]
	if biomePool and #biomePool > 0 then
		return biomePool, RuntimeNodeWeightsByBiome[biome]
	end
	return RuntimeNodeSharedPool, RuntimeNodeSharedWeights
end

local function getRuntimeNodeAssemblyPool(biome: string): ({ string }, { number }?)
	local biomePool = RuntimeNodeAssemblyPoolByBiome[biome]
	if biomePool and #biomePool > 0 then
		return biomePool, RuntimeNodeAssemblyWeightsByBiome[biome]
	end
	return RuntimeNodeAssemblySharedPool, RuntimeNodeAssemblySharedWeights
end

local function runStructureSieve(columns: { [string]: TileColumn }, config: WorldConfig, seed: number)
	StructureSieve({
		PrefabRegistry = PrefabRegistry,
		RuntimeNatureChanceByBiome = RuntimeNatureChanceByBiome,
		RuntimeNatureWeightsByBiome = RuntimeNatureWeightsByBiome,
		chooseWeightedRuntimePrefabId = chooseWeightedRuntimePrefabId,
	}, columns, config, seed)
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

local function isHabitationStructureName(nameLower: string): boolean
	return string.find(nameLower, "house", 1, true) ~= nil
		or string.find(nameLower, "townhouse", 1, true) ~= nil
		or string.find(nameLower, "cabin", 1, true) ~= nil
		or string.find(nameLower, "hut", 1, true) ~= nil
		or string.find(nameLower, "shack", 1, true) ~= nil
		or string.find(nameLower, "chalet", 1, true) ~= nil
		or string.find(nameLower, "cottage", 1, true) ~= nil
		or string.find(nameLower, "barn", 1, true) ~= nil
end

local function isEnvironmentStructureName(nameLower: string): boolean
	return string.find(nameLower, "lamp", 1, true) ~= nil
		or string.find(nameLower, "lantern", 1, true) ~= nil
		or string.find(nameLower, "well", 1, true) ~= nil
		or string.find(nameLower, "fence", 1, true) ~= nil
		or string.find(nameLower, "cart", 1, true) ~= nil
		or string.find(nameLower, "campfire", 1, true) ~= nil
		or string.find(nameLower, "camp", 1, true) ~= nil
		or string.find(nameLower, "gate", 1, true) ~= nil
		or string.find(nameLower, "plaza", 1, true) ~= nil
		or string.find(nameLower, "marker", 1, true) ~= nil
end

local function getRuntimeStructureScale(definition: { Category: string, Name: string }): number
	if definition.Category ~= "Structure" then
		return 1
	end
	local lowered = string.lower(definition.Name)
	if isHabitationStructureName(lowered) then
		return HABITATION_STRUCTURE_SCALE
	end
	if isEnvironmentStructureName(lowered) then
		return ENVIRONMENT_STRUCTURE_SCALE
	end
	return STRUCTURE_PREFAB_SCALE
end

local function runSurfaceSmoothingSieve(columns: { [string]: TileColumn }, config: WorldConfig)
	SurfaceSmoothingSieve({
		makeColumnKey = makeColumnKey,
		smoothstep = smoothstep,
		snapHeight = snapHeight,
		isMountainBiome = isMountainBiome,
		TerrainTuning = TerrainTuning,
	}, columns, config, nil)
end

local function runPathSieve(
	columns: { [string]: TileColumn },
	config: WorldConfig,
	seed: number
): (TileColumn?, { TileColumn }, number, { PathRoute })
	return PathSieve({
		getCenterSolidColumn = getCenterSolidColumn,
		TerrainTuning = TerrainTuning,
		randomNodeRadiusScale = randomNodeRadiusScale,
		getNearestSolidColumnToTarget = getNearestSolidColumnToTarget,
		angularDistance = angularDistance,
		hasNodeOverlap = hasNodeOverlap,
		generateWindingPathNodes = generateWindingPathNodes,
		getSolidColumnNear = getSolidColumnNear,
		makeColumnKey = makeColumnKey,
		smoothstep = smoothstep,
		snapHeight = snapHeight,
		isMountainBiome = isMountainBiome,
		isPlainsBiome = isPlainsBiome,
		isForestBiome = isForestBiome,
		RuntimeNodeStructuresEnabled = RuntimeNodeStructuresEnabled,
		RuntimeNodeAssemblyPlacement = RuntimeNodeAssemblyPlacement,
		RuntimeNodeAssemblyDefinitions = RuntimeNodeAssemblyDefinitions,
		chooseWeightedRuntimePrefabId = chooseWeightedRuntimePrefabId,
		getRuntimeNodeAssemblyPool = getRuntimeNodeAssemblyPool,
		getRuntimeNodePool = getRuntimeNodePool,
		getRuntimeStructureScale = getRuntimeStructureScale,
		getBiomeMaterials = getBiomeMaterials,
		PrefabRegistry = PrefabRegistry,
		getPathNodeBaseRadiusTiles = getPathNodeBaseRadiusTiles,
	}, columns, config, seed)
end

local function runStructureFootprintFlatteningSieve(columns: { [string]: TileColumn }, config: WorldConfig)
	StructureFootprintFlatteningSieve({
		StructureFlatteningSettings = StructureFlatteningSettings,
		PrefabRegistry = PrefabRegistry,
		getRuntimeStructureScale = getRuntimeStructureScale,
		snapHeight = snapHeight,
		makeColumnKey = makeColumnKey,
	}, columns, config, nil)
end

local function runHeightSnapSieve(columns: { [string]: TileColumn })
	HeightSnapSieve({
		snapHeight = snapHeight,
	}, columns, nil, nil)
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

local function collectNearestChunks(
	chunks: { ChunkData },
	centerChunkX: number,
	centerChunkZ: number,
	maxCount: number
): { ChunkData }
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
	part.Position = Vector3.new(
		(xTileMin + xTileMax) * 0.5 * tileSize,
		(bottomY + topY) * 0.5,
		(zTileMin + zTileMax) * 0.5 * tileSize
	)
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

		local active = {} :: {
			[string]: { XMin: number, XMax: number, ZMin: number, ZMax: number, SurfaceY: number, BottomY: number },
		}
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

			local nextActive = {} :: {
				[string]: { XMin: number, XMax: number, ZMin: number, ZMax: number, SurfaceY: number, BottomY: number },
			}
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
	runStructureFootprintFlatteningSieve(columns, config)
	runHeightSnapSieve(columns)

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

	WorldSpawnServiceServer.ClearPlayerChunks(player)

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
	spawnManualStructurePreview(CurrentWorld)
	WorldSpawnServiceServer.InitializeWorld(CurrentWorld)
	if WorldRoot then
		WorldRoot:SetAttribute("WorldSpawnPointCount", WorldSpawnServiceServer.GetSpawnPointCount())
	end

	print(
		string.format(
			"[WorldService] Generated floating island seed=%d chunks=%d collisionParts=%d pathEndpoints=%d pathNodes=%d",
			seed,
			if CurrentWorld then #CurrentWorld.Chunks else 0,
			if CurrentWorld then CurrentWorld.CollisionParts else 0,
			if CurrentWorld then #CurrentWorld.PathEndpoints else 0,
			if CurrentWorld then CurrentWorld.PathNodeCount else 0
		)
	)

	broadcastWorld()
	return seed
end

function WorldServiceServer.init()
	ensureWorldRoots()
	local initialSeed = deriveServerSeed()
	WorldServiceServer.Regenerate(initialSeed)
end

Players.PlayerAdded:Connect(function(player)
	WorldSpawnServiceServer.ClearPlayerChunks(player)

	if ActiveSpawnLocation then
		player.RespawnLocation = ActiveSpawnLocation
	end

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			-- Ensure spawnpoint wins even if other systems touch spawn flow.
			if character.Parent and player.Parent then
				teleportPlayerToSpawn(player)
			end
		end)
	end)

	if CurrentWorld then
		fireWorldToPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	WorldSpawnServiceServer.ClearPlayerChunks(player)
end)

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "RequestWorld" then
		fireWorldToPlayer(player)
	elseif action == "RequestChunks" then
		sendRequestedChunksToPlayer(player, payload)
	elseif action == "ChunkLoaded" then
		local payloadSeed = payload and payload.Seed
		if type(payloadSeed) == "number" and payloadSeed ~= CurrentSeed then
			return
		end
		local chunkX = payload and payload.ChunkX
		local chunkZ = payload and payload.ChunkZ
		if type(chunkX) == "number" and type(chunkZ) == "number" then
			WorldSpawnServiceServer.NotifyChunkLoaded(player, chunkX, chunkZ)
		end
	elseif action == "ChunkUnloaded" then
		local payloadSeed = payload and payload.Seed
		if type(payloadSeed) == "number" and payloadSeed ~= CurrentSeed then
			return
		end
		local chunkX = payload and payload.ChunkX
		local chunkZ = payload and payload.ChunkZ
		if type(chunkX) == "number" and type(chunkZ) == "number" then
			WorldSpawnServiceServer.NotifyChunkUnloaded(player, chunkX, chunkZ)
		end
	elseif action == "ResetLoadedChunks" then
		local payloadSeed = payload and payload.Seed
		if type(payloadSeed) == "number" and payloadSeed ~= CurrentSeed then
			return
		end
		WorldSpawnServiceServer.ClearPlayerChunks(player)
	elseif action == "RequestRegenerate" then
		if RunService:IsStudio() then
			local override = payload and payload.Seed
			WorldServiceServer.Regenerate(if type(override) == "number" then override else nil)
		end
	end
end)

return table.freeze(WorldServiceServer)
