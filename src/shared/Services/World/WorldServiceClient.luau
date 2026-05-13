--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Signal = require(game:GetService("ReplicatedStorage").Classes.Modifier.Signal)
local API = script.Parent:WaitForChild("WorldEndpoint") :: RemoteEvent
local PrefabRenderer = require(script.Parent.Prefabs.PrefabRenderer)

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

type PathPointPayload = {
	X: number,
	Z: number,
	Height: number,
	RadiusScale: number?,
	IsStructureNode: boolean?,
	PathRadiusTiles: number?,
	FlattenRadiusTiles: number?,
	CarveHeight: number?,
}

type PathRoutePayload = { PathPointPayload }

type SpawnDebugRegenerateOptions = {
	EnemyBaseLevel: number?,
	GenerationType: string?,
}

type WorldRegenerateOptions = {
	Biome: string?,
	SpawnDebug: SpawnDebugRegenerateOptions?,
}

local WorldServiceClient = {}

local LocalPlayer = Players.LocalPlayer
local CurrentSeed = 0
local CurrentConfig: WorldConfig? = nil
local LoadedChunks = {} :: { [string]: ChunkData }
local RequestedChunks = {} :: { [string]: boolean }
local ChunkFolders = {} :: { [string]: Folder }
local ChunkWaterfallFolders = {} :: { [string]: Folder }
local LoadedColumnsByKey = {} :: { [string]: TileColumnPayload }
local ChunkColumnKeys = {} :: { [string]: { string } }
local WorldChanged = Signal.new()
local RenderRoot: Folder? = nil
local PathDebugRoot: Folder? = nil
local StreamHeartbeatConnection: RBXScriptConnection? = nil
local LastStreamUpdateAt = 0
local SpawnChunkX = 0
local SpawnChunkZ = 0
local SuggestedStreamRadius = 22
local SuggestedUnloadRadius = 28

local STREAM_UPDATE_INTERVAL = 0.24
local STREAM_REQUEST_BUDGET = 16
local DEBUG_NODE_ELEVATION = 6
local WATERFALL_SIDE_INSET_RATIO = 0.08
local WATERFALL_THICKNESS_RATIO = 0.16
local WATERFALL_FACE_OFFSET_RATIO = 0.03
local WATERFALL_MIN_DROP = 1
local WATERFALL_EDGE_EXTRA_DROP = 2
local STUD_UNIT = 1
local MIN_PART_SIZE = 1
local PATH_VISUAL_WIDTH_SCALE = 2
local TREASURE_CHEST_OPEN_ANGLE_DEGREES = -108
local TREASURE_CHEST_OPEN_FORWARD_SHIFT = 0.55
local TREASURE_CHEST_OPEN_VERTICAL_LIFT = 0.5
local TREASURE_CHEST_OPEN_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TREASURE_CHEST_LOCK_FADE_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local BiomeColors = {
	TemperateGrassland = {
		Surface = Color3.fromRGB(87, 130, 74),
		Fill = Color3.fromRGB(112, 112, 122),
		Water = Color3.fromRGB(76, 147, 255),
	},
	PineHighlands = {
		Surface = Color3.fromRGB(78, 117, 88),
		Fill = Color3.fromRGB(110, 110, 124),
		Water = Color3.fromRGB(82, 156, 255),
	},
	Forest = {
		Surface = Color3.fromRGB(54, 102, 60),
		Fill = Color3.fromRGB(96, 101, 110),
		Water = Color3.fromRGB(66, 128, 209),
	},
	Alpine = {
		Surface = Color3.fromRGB(228, 232, 240),
		Fill = Color3.fromRGB(124, 124, 136),
		Water = Color3.fromRGB(140, 190, 255),
	},
	HighlandDesert = {
		Surface = Color3.fromRGB(199, 170, 106),
		Fill = Color3.fromRGB(124, 118, 108),
		Water = Color3.fromRGB(112, 169, 250),
	},
	Marshland = {
		Surface = Color3.fromRGB(92, 108, 78),
		Fill = Color3.fromRGB(106, 103, 96),
		Water = Color3.fromRGB(68, 136, 214),
	},
}

local function chunkKey(chunkX: number, chunkZ: number): string
	return tostring(chunkX) .. ":" .. tostring(chunkZ)
end

local function columnKey(tileX: number, tileZ: number): string
	return tostring(tileX) .. ":" .. tostring(tileZ)
end

local function resolveMaterial(materialName: string, fallback: Enum.Material): Enum.Material
	local success, value = pcall(function()
		return Enum.Material[materialName]
	end)
	if success and value then
		return value
	end
	return fallback
end

local function ensureRenderRoot(): Folder
	if RenderRoot and RenderRoot.Parent then
		return RenderRoot
	end

	local worldRoot = Workspace:WaitForChild("WorldService") :: Folder
	local visualRoot = worldRoot:WaitForChild("VisualRoot") :: Folder
	local folderName = string.format("Client_%d", LocalPlayer.UserId)
	local existing = visualRoot:FindFirstChild(folderName)
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = folderName
		existing.Parent = visualRoot
	end

	RenderRoot = existing :: Folder
	return RenderRoot
end

local function ensurePathDebugRoot(): Folder
	if PathDebugRoot and PathDebugRoot.Parent then
		return PathDebugRoot
	end

	local root = ensureRenderRoot()
	local existing = root:FindFirstChild("PathDebug")
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = "PathDebug"
		existing.Parent = root
	end

	PathDebugRoot = existing :: Folder
	return PathDebugRoot
end

local function clearRenderedWorld()
	local hasLoadedChunks = false
	for _ in pairs(LoadedChunks) do
		hasLoadedChunks = true
		break
	end
	if hasLoadedChunks then
		API:FireServer("ResetLoadedChunks", {
			Seed = CurrentSeed,
		})
	end

	local root = ensureRenderRoot()
	for _, child in ipairs(root:GetChildren()) do
		child:Destroy()
	end
	PathDebugRoot = nil
	table.clear(LoadedChunks)
	table.clear(RequestedChunks)
	table.clear(ChunkFolders)
	table.clear(ChunkWaterfallFolders)
	table.clear(LoadedColumnsByKey)
	table.clear(ChunkColumnKeys)
	LastStreamUpdateAt = 0
	SpawnChunkX = 0
	SpawnChunkZ = 0
end

local function snapNumber(value: number): number
	if value >= 0 then
		return math.floor((value / STUD_UNIT) + 0.5) * STUD_UNIT
	end
	return math.ceil((value / STUD_UNIT) - 0.5) * STUD_UNIT
end

local function snapSizeAxis(value: number): number
	return math.max(MIN_PART_SIZE, math.abs(snapNumber(value)))
end

local function snapSize(size: Vector3): Vector3
	return Vector3.new(snapSizeAxis(size.X), snapSizeAxis(size.Y), snapSizeAxis(size.Z))
end

local function snapPosition(position: Vector3): Vector3
	-- Preserve exact Y so stacked parts (fill + cap) keep their intended vertical relationship.
	return Vector3.new(snapNumber(position.X), position.Y, snapNumber(position.Z))
end

local function snapCFrame(cframe: CFrame): CFrame
	local snappedPosition = snapPosition(cframe.Position)
	return CFrame.fromMatrix(snappedPosition, cframe.XVector, cframe.YVector, cframe.ZVector)
end

local function applyStudSurfaces(part: Part)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
end

local function createVisualPart(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	material: Enum.Material,
	color: Color3,
	transparency: number
)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	part.Size = snapSize(size)
	part.Position = snapPosition(position)
	applyStudSurfaces(part)
	part.Parent = parent
	return part
end

local function createDebugPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	transparency: number
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = snapSize(size)
	part.CFrame = snapCFrame(cframe)
	applyStudSurfaces(part)
	part.Parent = parent
	return part
end

local function getBiomePalette(biome: string)
	return BiomeColors[biome] or BiomeColors.TemperateGrassland
end

local function registerChunkColumns(chunkIdentifier: string, chunk: ChunkData)
	local keys = {} :: { string }
	for _, column in ipairs(chunk.Columns) do
		local key = columnKey(column.X, column.Z)
		LoadedColumnsByKey[key] = column
		table.insert(keys, key)
	end
	ChunkColumnKeys[chunkIdentifier] = keys
end

local function unregisterChunkColumns(chunkIdentifier: string)
	local keys = ChunkColumnKeys[chunkIdentifier]
	if not keys then
		return
	end
	for _, key in ipairs(keys) do
		LoadedColumnsByKey[key] = nil
	end
	ChunkColumnKeys[chunkIdentifier] = nil
end

local function getNeighborColumnIfKnown(
	tileX: number,
	tileZ: number,
	sourceChunkX: number,
	sourceChunkZ: number
): (TileColumnPayload?, boolean)
	if not CurrentConfig then
		return nil, false
	end

	local neighborChunkX = math.floor(tileX / CurrentConfig.ChunkSize)
	local neighborChunkZ = math.floor(tileZ / CurrentConfig.ChunkSize)
	if neighborChunkX == sourceChunkX and neighborChunkZ == sourceChunkZ then
		return LoadedColumnsByKey[columnKey(tileX, tileZ)], true
	end

	local neighborChunkKey = chunkKey(neighborChunkX, neighborChunkZ)
	if LoadedChunks[neighborChunkKey] == nil then
		return nil, false
	end
	return LoadedColumnsByKey[columnKey(tileX, tileZ)], true
end

local function getOrCreateChunkWaterfallFolder(chunkIdentifier: string, chunkFolder: Folder): Folder
	local existing = ChunkWaterfallFolders[chunkIdentifier]
	if existing and existing.Parent then
		return existing
	end

	local folder: Folder = chunkFolder:FindFirstChild("Waterfalls") :: Folder
	if not folder then
		folder = Instance.new("Folder") :: Folder
		folder.Name = "Waterfalls"
		folder.Parent = chunkFolder
	end
	local typedFolder = folder :: Folder
	ChunkWaterfallFolders[chunkIdentifier] = typedFolder
	return typedFolder
end

local function renderChunkWaterfalls(chunk: ChunkData)
	if not CurrentConfig then
		return
	end

	local chunkIdentifier = chunkKey(chunk.ChunkX, chunk.ChunkZ)
	local chunkFolder = ChunkFolders[chunkIdentifier]
	if not chunkFolder then
		return
	end
	local waterfallFolder = getOrCreateChunkWaterfallFolder(chunkIdentifier, chunkFolder)
	for _, child in ipairs(waterfallFolder:GetChildren()) do
		child:Destroy()
	end

	local tileSize = CurrentConfig.TileSize
	local sideInset = math.max(0.08, tileSize * WATERFALL_SIDE_INSET_RATIO)
	local thickness = math.max(0.3, tileSize * WATERFALL_THICKNESS_RATIO)
	local faceOffset = math.max(0.05, tileSize * WATERFALL_FACE_OFFSET_RATIO)
	local directions = {
		{ Name = "PX", DX = 1, DZ = 0 },
		{ Name = "NX", DX = -1, DZ = 0 },
		{ Name = "PZ", DX = 0, DZ = 1 },
		{ Name = "NZ", DX = 0, DZ = -1 },
	}

	for _, column in ipairs(chunk.Columns) do
		if not column.Solid or not column.HasWater then
			continue
		end

		local palette = getBiomePalette(column.Biome)
		local sourceTopY = column.SurfaceY
		for _, direction in ipairs(directions) do
			local neighborX = column.X + direction.DX
			local neighborZ = column.Z + direction.DZ
			local neighborColumn, neighborKnown =
				getNeighborColumnIfKnown(neighborX, neighborZ, chunk.ChunkX, chunk.ChunkZ)
			if not neighborKnown then
				continue
			end

			local targetBottomY: number? = nil
			if neighborColumn and neighborColumn.Solid then
				if neighborColumn.SurfaceY <= (column.SurfaceY - WATERFALL_MIN_DROP) then
					targetBottomY = neighborColumn.SurfaceY
				end
			else
				targetBottomY = column.BottomY - WATERFALL_EDGE_EXTRA_DROP
			end
			if targetBottomY == nil then
				continue
			end
			if targetBottomY >= sourceTopY - 0.2 then
				continue
			end

			local sizeX = tileSize - sideInset * 2
			local sizeZ = tileSize - sideInset * 2
			local centerX = column.X * tileSize
			local centerZ = column.Z * tileSize
			if direction.DX ~= 0 then
				sizeX = thickness
				centerX += direction.DX * (tileSize * 0.5 - thickness * 0.5 + faceOffset)
			else
				sizeZ = thickness
				centerZ += direction.DZ * (tileSize * 0.5 - thickness * 0.5 + faceOffset)
			end

			local fallHeight = sourceTopY - targetBottomY
			createVisualPart(
				waterfallFolder,
				string.format("Waterfall_%d_%d_%s", column.X, column.Z, direction.Name),
				Vector3.new(sizeX, fallHeight, sizeZ),
				Vector3.new(centerX, targetBottomY + fallHeight * 0.5, centerZ),
				Enum.Material.SmoothPlastic,
				palette.Water,
				0
			)
		end
	end
end

local function refreshWaterfallsAroundChunk(chunkX: number, chunkZ: number)
	for dz = -1, 1 do
		for dx = -1, 1 do
			local key = chunkKey(chunkX + dx, chunkZ + dz)
			local chunk = LoadedChunks[key]
			if chunk then
				renderChunkWaterfalls(chunk)
			end
		end
	end
end

local function renderColumn(column: TileColumnPayload, parent: Folder)
	if not CurrentConfig or not column.Solid then
		return
	end

	local tileSize = CurrentConfig.TileSize
	local x = column.X * tileSize
	local z = column.Z * tileSize
	local columnHeight = math.max(1, column.SurfaceY - column.BottomY + 1)
	local palette = getBiomePalette(column.Biome)

	local surfaceMaterial = resolveMaterial(column.SurfaceMaterial, Enum.Material.Grass)
	if column.IsPath and column.PathMaterial then
		surfaceMaterial = resolveMaterial(column.PathMaterial, surfaceMaterial)
	end
	local surfaceColor = palette.Surface
	if column.IsPath then
		if surfaceMaterial == Enum.Material.Rock or surfaceMaterial == Enum.Material.Slate then
			surfaceColor = Color3.fromRGB(138, 140, 147)
		elseif surfaceMaterial == Enum.Material.Sand or surfaceMaterial == Enum.Material.Sandstone then
			surfaceColor = Color3.fromRGB(221, 194, 133)
		elseif surfaceMaterial == Enum.Material.Ground then
			surfaceColor = Color3.fromRGB(126, 113, 93)
		end
	end
	if column.HasWater then
		surfaceMaterial = Enum.Material.SmoothPlastic
		surfaceColor = palette.Water
	end
	local isWaterTile = column.HasWater

	local fillMaterial = resolveMaterial(column.FillMaterial, Enum.Material.Rock)
	local fillColor = palette.Fill
	local fillHeight = math.max(0, columnHeight - 1)
	if fillHeight > 0 then
		local fillCenterY = column.BottomY + (fillHeight - 1) * 0.5
		createVisualPart(
			parent,
			string.format("Tile_%d_%d_Stone", column.X, column.Z),
			Vector3.new(tileSize, fillHeight, tileSize),
			Vector3.new(x, fillCenterY, z),
			fillMaterial,
			fillColor,
			0
		)
	end

	if isWaterTile then
		createVisualPart(
			parent,
			string.format("Tile_%d_%d_Water", column.X, column.Z),
			Vector3.new(tileSize, 1, tileSize),
			Vector3.new(x, column.SurfaceY - 0.5, z),
			Enum.Material.SmoothPlastic,
			palette.Water,
			0.08
		)
	else
		createVisualPart(
			parent,
			string.format("Tile_%d_%d_Cap", column.X, column.Z),
			Vector3.new(tileSize, 1, tileSize),
			Vector3.new(x, column.SurfaceY, z),
			surfaceMaterial,
			surfaceColor,
			0
		)
	end

	local undersideHeight = math.max(5, math.floor(tileSize * 0.8 + columnHeight * 0.35))
	local undersideCenterY = column.BottomY - (undersideHeight + 1) * 0.5
	createVisualPart(
		parent,
		string.format("Tile_%d_%d_Underside", column.X, column.Z),
		Vector3.new(tileSize, undersideHeight, tileSize),
		Vector3.new(x, undersideCenterY, z),
		Enum.Material.Slate,
		Color3.fromRGB(95, 95, 108),
		0
	)

	if column.StructureTag then
		PrefabRenderer.Render(column.StructureTag, parent, {
			Position = Vector3.new(x, column.SurfaceY, z),
			TileSize = tileSize,
			SurfaceY = column.SurfaceY,
			Biome = column.Biome,
			ColumnX = column.X,
			ColumnZ = column.Z,
			Seed = CurrentSeed,
			NameSuffix = string.format("%d_%d", column.X, column.Z),
		})
	end
end

local function renderPathDebug(pathRoutes: { PathRoutePayload }?)
	if not CurrentConfig then
		return
	end

	local debugRoot = ensurePathDebugRoot()
	for _, child in ipairs(debugRoot:GetChildren()) do
		child:Destroy()
	end
end

local function getChunkFromWorldPosition(position: Vector3): (number, number)
	if not CurrentConfig then
		return SpawnChunkX, SpawnChunkZ
	end

	local tileSize = CurrentConfig.TileSize
	local tileX = position.X / tileSize
	local tileZ = position.Z / tileSize
	return math.floor(tileX / CurrentConfig.ChunkSize), math.floor(tileZ / CurrentConfig.ChunkSize)
end

local function getStreamCenterChunk(): (number, number)
	local character = LocalPlayer.Character
	if not character then
		return SpawnChunkX, SpawnChunkZ
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return getChunkFromWorldPosition(rootPart.Position)
	end

	return SpawnChunkX, SpawnChunkZ
end

local function requestChunkBatch(requests: { { ChunkX: number, ChunkZ: number } })
	if #requests <= 0 then
		return
	end
	API:FireServer("RequestChunks", {
		Chunks = requests,
	})
end

local function teleportLocalPlayerToSpawn()
	local worldRoot = Workspace:FindFirstChild("WorldService")
	if not worldRoot then
		return
	end

	local spawn = worldRoot:FindFirstChild("IslandSpawnPoint")
	if not spawn or not spawn:IsA("SpawnLocation") then
		return
	end

	local character = LocalPlayer.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local lookVector = Vector3.new(spawn.CFrame.LookVector.X, 0, spawn.CFrame.LookVector.Z)
	if lookVector.Magnitude < 0.001 then
		lookVector = Vector3.new(0, 0, -1)
	else
		lookVector = lookVector.Unit
	end

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	local targetPosition = spawn.Position + Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(targetPosition, targetPosition + lookVector))
end

local function updateStreaming(force: boolean)
	if not CurrentConfig then
		return
	end

	local now = os.clock()
	if not force and (now - LastStreamUpdateAt) < STREAM_UPDATE_INTERVAL then
		return
	end
	LastStreamUpdateAt = now

	local centerChunkX, centerChunkZ = getStreamCenterChunk()
	local maxChunkRadius = math.ceil(CurrentConfig.RadiusTiles / CurrentConfig.ChunkSize) + 1
	local streamRadius = math.max(3, math.min(SuggestedStreamRadius, maxChunkRadius))
	local unloadRadius = math.max(streamRadius + 2, SuggestedUnloadRadius)

	local pending = {} :: { { ChunkX: number, ChunkZ: number, DistanceSq: number, Key: string } }
	for dz = -streamRadius, streamRadius do
		for dx = -streamRadius, streamRadius do
			local distanceSq = dx * dx + dz * dz
			if distanceSq > streamRadius * streamRadius then
				continue
			end

			local chunkX = centerChunkX + dx
			local chunkZ = centerChunkZ + dz
			if math.abs(chunkX) > maxChunkRadius or math.abs(chunkZ) > maxChunkRadius then
				continue
			end

			local chunkCenterTileX = chunkX * CurrentConfig.ChunkSize + CurrentConfig.ChunkSize * 0.5
			local chunkCenterTileZ = chunkZ * CurrentConfig.ChunkSize + CurrentConfig.ChunkSize * 0.5
			local chunkCenterDistance =
				math.sqrt(chunkCenterTileX * chunkCenterTileX + chunkCenterTileZ * chunkCenterTileZ)
			if chunkCenterDistance > CurrentConfig.RadiusTiles + CurrentConfig.ChunkSize then
				continue
			end

			local key = chunkKey(chunkX, chunkZ)
			if not LoadedChunks[key] and not RequestedChunks[key] then
				table.insert(pending, {
					ChunkX = chunkX,
					ChunkZ = chunkZ,
					DistanceSq = distanceSq,
					Key = key,
				})
			end
		end
	end

	table.sort(
		pending,
		function(
			a: { ChunkX: number, ChunkZ: number, DistanceSq: number, Key: string },
			b: { ChunkX: number, ChunkZ: number, DistanceSq: number, Key: string }
		): boolean
			return a.DistanceSq < b.DistanceSq
		end
	)

	local requests = {} :: { { ChunkX: number, ChunkZ: number } }
	local requestCount = math.min(STREAM_REQUEST_BUDGET, #pending)
	for index = 1, requestCount do
		local request = pending[index]
		RequestedChunks[request.Key] = true
		table.insert(requests, {
			ChunkX = request.ChunkX,
			ChunkZ = request.ChunkZ,
		})
	end
	requestChunkBatch(requests)

	for key, chunk in pairs(LoadedChunks) do
		local dx = chunk.ChunkX - centerChunkX
		local dz = chunk.ChunkZ - centerChunkZ
		local distanceSq = dx * dx + dz * dz
		if distanceSq > unloadRadius * unloadRadius then
			unregisterChunkColumns(key)
			local folder = ChunkFolders[key]
			if folder then
				folder:Destroy()
			end
			ChunkWaterfallFolders[key] = nil
			ChunkFolders[key] = nil
			LoadedChunks[key] = nil
			RequestedChunks[key] = nil
			API:FireServer("ChunkUnloaded", {
				ChunkX = chunk.ChunkX,
				ChunkZ = chunk.ChunkZ,
				Seed = CurrentSeed,
			})
			refreshWaterfallsAroundChunk(chunk.ChunkX, chunk.ChunkZ)
			WorldChanged:Fire("UnloadChunk", chunk)
		end
	end
end

local function loadChunk(chunk: ChunkData)
	local root = ensureRenderRoot()
	local key = chunkKey(chunk.ChunkX, chunk.ChunkZ)
	if LoadedChunks[key] then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = string.format("Chunk_%d_%d", chunk.ChunkX, chunk.ChunkZ)
	folder.Parent = root

	for _, column in ipairs(chunk.Columns) do
		renderColumn(column, folder)
	end

	LoadedChunks[key] = chunk
	RequestedChunks[key] = true
	ChunkFolders[key] = folder
	registerChunkColumns(key, chunk)
	API:FireServer("ChunkLoaded", {
		ChunkX = chunk.ChunkX,
		ChunkZ = chunk.ChunkZ,
		Seed = CurrentSeed,
	})
	refreshWaterfallsAroundChunk(chunk.ChunkX, chunk.ChunkZ)
end

local function getChunkCoordsFromTile(tileX: number, tileZ: number): (number?, number?)
	if not CurrentConfig then
		return nil, nil
	end
	return math.floor(tileX / CurrentConfig.ChunkSize), math.floor(tileZ / CurrentConfig.ChunkSize)
end

local function getChunkFolderForTile(tileX: number, tileZ: number): Folder?
	local chunkX, chunkZ = getChunkCoordsFromTile(tileX, tileZ)
	if chunkX == nil or chunkZ == nil then
		return nil
	end
	local key = chunkKey(chunkX, chunkZ)
	return ChunkFolders[key]
end

local function removeColumnFromLoadedChunk(tileX: number, tileZ: number)
	local chunkX, chunkZ = getChunkCoordsFromTile(tileX, tileZ)
	if chunkX == nil or chunkZ == nil then
		return
	end
	local key = chunkKey(chunkX, chunkZ)
	local chunk = LoadedChunks[key]
	if not chunk then
		return
	end

	local nextColumns = {} :: { TileColumnPayload }
	for _, column in ipairs(chunk.Columns) do
		if not (column.X == tileX and column.Z == tileZ) then
			table.insert(nextColumns, column)
		end
	end
	chunk.Columns = nextColumns
	LoadedColumnsByKey[columnKey(tileX, tileZ)] = nil
end

local function collectRenderedTileInstances(tileX: number, tileZ: number): { Instance }
	local chunkFolder = getChunkFolderForTile(tileX, tileZ)
	if not chunkFolder then
		return {}
	end

	local targets = {} :: { Instance }
	local seen = {} :: { [Instance]: boolean }
	local stoneName = string.format("Tile_%d_%d_Stone", tileX, tileZ)
	local fillName = string.format("Tile_%d_%d_Fill", tileX, tileZ)
	local capName = string.format("Tile_%d_%d_Cap", tileX, tileZ)
	local waterName = string.format("Tile_%d_%d_Water", tileX, tileZ)
	local undersideName = string.format("Tile_%d_%d_Underside", tileX, tileZ)
	local waterfallPrefix = string.format("Waterfall_%d_%d_", tileX, tileZ)

	for _, child in ipairs(chunkFolder:GetChildren()) do
		if child:IsA("BasePart") then
			if
				child.Name == stoneName
				or child.Name == fillName
				or child.Name == capName
				or child.Name == waterName
				or child.Name == undersideName
				or string.sub(child.Name, 1, #waterfallPrefix) == waterfallPrefix
			then
				if not seen[child] then
					seen[child] = true
					table.insert(targets, child)
				end
			end
		end
	end

	for _, descendant in ipairs(chunkFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			if string.sub(part.Name, 1, #waterfallPrefix) == waterfallPrefix then
				if not seen[part] then
					seen[part] = true
					table.insert(targets, part)
				end
			end
		elseif descendant:IsA("Model") then
			local model = descendant :: Model
			if model:GetAttribute("ColumnX") == tileX and model:GetAttribute("ColumnZ") == tileZ then
				if not seen[model] then
					seen[model] = true
					table.insert(targets, model)
				end
			end
		end
	end

	return targets
end

local function animateInstanceDrop(instance: Instance, dropStuds: number, durationSeconds: number)
	if instance:IsA("BasePart") then
		local part = instance :: BasePart
		local goal = { CFrame = part.CFrame * CFrame.new(0, -dropStuds, 0) }
		TweenService:Create(part, TweenInfo.new(durationSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), goal):Play()
		return
	end

	if instance:IsA("Model") then
		local model = instance :: Model
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local part = descendant :: BasePart
				local goal = { CFrame = part.CFrame * CFrame.new(0, -dropStuds, 0) }
				TweenService:Create(
					part,
					TweenInfo.new(durationSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					goal
				):Play()
			end
		end
	end
end

local function handleCollapseTiles(payload: { [string]: any }?)
	if not payload then
		return
	end
	local tiles = payload.Tiles
	if type(tiles) ~= "table" then
		return
	end

	local animate = payload.Animate == true
	local dropStuds = if type(payload.FallDistanceStuds) == "number" then math.max(1, payload.FallDistanceStuds) else 100
	local durationSeconds = if type(payload.FallDurationSeconds) == "number"
		then math.max(0.2, payload.FallDurationSeconds)
		else 2.2

	local touchedChunks = {} :: { [string]: { X: number, Z: number } }
	for _, tile in ipairs(tiles) do
		if type(tile) == "table" and type(tile.X) == "number" and type(tile.Z) == "number" then
			local tileX = math.floor(tile.X)
			local tileZ = math.floor(tile.Z)
			local instances = collectRenderedTileInstances(tileX, tileZ)
			removeColumnFromLoadedChunk(tileX, tileZ)

			local chunkX, chunkZ = getChunkCoordsFromTile(tileX, tileZ)
			if chunkX ~= nil and chunkZ ~= nil then
				touchedChunks[chunkKey(chunkX, chunkZ)] = { X = chunkX, Z = chunkZ }
			end

			if animate then
				for _, instance in ipairs(instances) do
					animateInstanceDrop(instance, dropStuds, durationSeconds)
				end
				task.delay(durationSeconds, function()
					for _, instance in ipairs(instances) do
						if instance and instance.Parent then
							instance:Destroy()
						end
					end
				end)
			else
				for _, instance in ipairs(instances) do
					if instance and instance.Parent then
						instance:Destroy()
					end
				end
			end
		end
	end

	for _, chunkPos in pairs(touchedChunks) do
		refreshWaterfallsAroundChunk(chunkPos.X, chunkPos.Z)
	end
end

local function findRenderedPrefabModel(prefabId: string, columnX: number, columnZ: number): Model?
	local root = ensureRenderRoot()
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Model") then
			local model = descendant :: Model
			if model:GetAttribute("PrefabId") == prefabId
				and model:GetAttribute("ColumnX") == columnX
				and model:GetAttribute("ColumnZ") == columnZ then
				return model
			end
		end
	end
	return nil
end

local function playTreasureClaimAnimation(payload: { [string]: any }?)
	if not payload then
		return
	end

	local prefabId = payload.PrefabId
	local columnX = payload.ColumnX
	local columnZ = payload.ColumnZ
	if type(prefabId) ~= "string" or type(columnX) ~= "number" or type(columnZ) ~= "number" then
		return
	end

	local model = findRenderedPrefabModel(prefabId, math.floor(columnX), math.floor(columnZ))
	if not model then
		return
	end

	local lidInstance = model:FindFirstChild("ChestLid")
	if not lidInstance or not lidInstance:IsA("BasePart") then
		return
	end

	local lid = lidInstance :: BasePart
	if lid:GetAttribute("ChestOpened") == true then
		return
	end
	lid:SetAttribute("ChestOpened", true)

	local openCFrame = lid.CFrame
		* CFrame.new(0, TREASURE_CHEST_OPEN_VERTICAL_LIFT, TREASURE_CHEST_OPEN_FORWARD_SHIFT)
		* CFrame.Angles(math.rad(TREASURE_CHEST_OPEN_ANGLE_DEGREES), 0, 0)
	TweenService:Create(lid, TREASURE_CHEST_OPEN_TWEEN, { CFrame = openCFrame }):Play()

	local lockInstance = model:FindFirstChild("ChestLock")
	if lockInstance and lockInstance:IsA("BasePart") then
		local lock = lockInstance :: BasePart
		TweenService:Create(lock, TREASURE_CHEST_LOCK_FADE_TWEEN, { Transparency = 1 }):Play()
	end
end

function WorldServiceClient.GetSeed(): number
	return CurrentSeed
end

function WorldServiceClient.GetConfig(): WorldConfig?
	return CurrentConfig
end

function WorldServiceClient.GetLoadedChunkCount(): number
	local count = 0
	for _ in pairs(LoadedChunks) do
		count += 1
	end
	return count
end

function WorldServiceClient.GetWorldChangedSignal()
	return WorldChanged
end

function WorldServiceClient.RequestRegenerate(seed: number?, options: WorldRegenerateOptions?)
	API:FireServer("RequestRegenerate", {
		Seed = seed,
		Biome = if options then options.Biome else nil,
		SpawnDebug = if options then options.SpawnDebug else nil,
	})
end

function WorldServiceClient.init(): ()
	ensureRenderRoot()
	API:FireServer("RequestWorld", {})
	if not StreamHeartbeatConnection then
		StreamHeartbeatConnection = RunService.Heartbeat:Connect(function()
			updateStreaming(false)
		end)
	end
end

API.OnClientEvent:Connect(function(action: string, payload: { [string]: any }?)
	if action == "ClearWorld" then
		clearRenderedWorld()
		CurrentConfig = nil
		WorldChanged:Fire("ClearWorld", nil)
	elseif action == "InitializeWorld" then
		if payload then
			CurrentSeed = payload.Seed or CurrentSeed
			CurrentConfig = payload.Config :: WorldConfig
			if type(payload.SpawnChunkX) == "number" then
				SpawnChunkX = math.floor(payload.SpawnChunkX)
			end
			if type(payload.SpawnChunkZ) == "number" then
				SpawnChunkZ = math.floor(payload.SpawnChunkZ)
			end
			if type(payload.StreamRadius) == "number" then
				SuggestedStreamRadius = math.max(3, math.floor(payload.StreamRadius))
			end
			if type(payload.UnloadRadius) == "number" then
				SuggestedUnloadRadius = math.max(SuggestedStreamRadius + 1, math.floor(payload.UnloadRadius))
			end
			renderPathDebug(payload.PathRoutes :: { PathRoutePayload }?)
		end
		WorldChanged:Fire("InitializeWorld", payload)
		updateStreaming(true)
		task.defer(teleportLocalPlayerToSpawn)
	elseif action == "LoadChunk" then
		if payload then
			loadChunk(payload :: ChunkData)
			WorldChanged:Fire("LoadChunk", payload)
			updateStreaming(false)
		end
	elseif action == "TreasureClaimed" then
		playTreasureClaimAnimation(payload)
	elseif action == "CollapseTiles" then
		handleCollapseTiles(payload)
	end
end)

return table.freeze(WorldServiceClient)
