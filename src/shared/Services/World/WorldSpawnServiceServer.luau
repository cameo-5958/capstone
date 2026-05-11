--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PrefabTypes = require(script.Parent.Prefabs.PrefabTypes)
local PrefabRegistry = require(script.Parent.Prefabs.PrefabRegistry)
local WorldSpawnSettings = require(script.Parent.WorldSpawnSettings)

local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)

type PrefabSpawnMarker = PrefabTypes.PrefabSpawnMarker
type EnemyMarkerConfig = PrefabTypes.EnemySpawnMarkerConfig
type TreasureMarkerConfig = PrefabTypes.TreasureSpawnMarkerConfig
type WorldSpawnSettingsType = WorldSpawnSettings.WorldSpawnSettings
type EnemyPool = WorldSpawnSettings.EnemyPool
type BiomeLevelRange = WorldSpawnSettings.BiomeLevelRange
type StackReward = WorldSpawnSettings.StackReward
type Entity = any

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

type WorldState = {
	Seed: number,
	Config: WorldConfig,
	Columns: { [string]: TileColumn },
}

type EnemyGeneratedData = {
	EnemyPath: string,
	Level: number,
	LootTableId: string?,
}

type TreasureStackGrant = {
	ItemKind: string,
	StackKey: string,
	Quantity: number,
	MaxStack: number?,
	Data: { [string]: any }?,
}

type TreasureGeneratedData = {
	LootTableId: string,
	StackGrants: { TreasureStackGrant },
	WeaponGrants: { string },
}

type SpawnPointState = {
	Id: string,
	Type: "Enemy" | "Treasure",
	Biome: string,
	ChunkX: number,
	ChunkZ: number,
	ColumnX: number,
	ColumnZ: number,
	PrefabId: string,
	MarkerId: string,
	Position: Vector3,
	CFrame: CFrame,
	Status: "Dormant" | "Active" | "Dead" | "Claimed",
	EnemyData: EnemyGeneratedData?,
	TreasureData: TreasureGeneratedData?,
	PromptActionText: string?,
	PromptObjectText: string?,
	ActiveEnemyUUID: string?,
	ActiveTreasureModel: Model?,
	PromptConnection: RBXScriptConnection?,
	GenerationToken: number,
}

local Settings = WorldSpawnSettings :: WorldSpawnSettingsType
local WorldSpawnServiceServer = {}

local SpawnPointsById = {} :: { [string]: SpawnPointState }
local SpawnPointIdsByChunk = {} :: { [string]: { string } }
local ChunkRefCounts = {} :: { [string]: number }
local PlayerLoadedChunks = {} :: { [Player]: { [string]: boolean } }

local SpawnRoot: Folder? = nil
local TreasureRoot: Folder? = nil
local DebugRoot: Folder? = nil
local ActiveGenerationToken = 0

local function chunkKey(chunkX: number, chunkZ: number): string
	return tostring(chunkX) .. ":" .. tostring(chunkZ)
end

local function foldHash(hash: number, value: number): number
	local nextHash = (hash * 48271 + value * 131 + 17) % 2147483647
	if nextHash <= 0 then
		nextHash += 2147483646
	end
	return nextHash
end

local function hashString(value: string, seed: number): number
	local hash = seed
	for i = 1, #value do
		hash = foldHash(hash, string.byte(value, i))
	end
	return hash
end

local function normalizeLevelRange(range: BiomeLevelRange): BiomeLevelRange
	local minValue = math.max(1, math.floor(range.Min))
	local maxValue = math.max(minValue, math.floor(range.Max))
	local stepValue = if type(range.Step) == "number" then math.max(1, math.floor(range.Step)) else 1
	return {
		Min = minValue,
		Max = maxValue,
		Step = stepValue,
	}
end

local function chooseWeightedIndex(weights: { number }, rng: Random): number?
	if #weights <= 0 then
		return nil
	end

	local totalWeight = 0
	for _, weight in ipairs(weights) do
		totalWeight += math.max(0, weight)
	end
	if totalWeight <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, totalWeight)
	local cursor = 0
	for index, weight in ipairs(weights) do
		cursor += math.max(0, weight)
		if roll <= cursor then
			return index
		end
	end
	return #weights
end

local function chooseWeightedEnemyPath(pool: EnemyPool, rng: Random): string?
	if not pool or #pool.Entries <= 0 then
		return nil
	end

	local weights = {}
	for _, entry in ipairs(pool.Entries) do
		table.insert(weights, entry.Weight or 1)
	end
	local chosenIndex = chooseWeightedIndex(weights, rng)
	if not chosenIndex then
		return nil
	end

	local selected = pool.Entries[chosenIndex]
	if type(selected.EnemyPath) ~= "string" or selected.EnemyPath == "" then
		return nil
	end

	return selected.EnemyPath
end

local function rollLevel(range: BiomeLevelRange, rng: Random): number
	local normalized = normalizeLevelRange(range)
	local stepValue = normalized.Step or 1
	local steps = math.floor((normalized.Max - normalized.Min) / stepValue)
	if steps <= 0 then
		return normalized.Min
	end

	local picked = rng:NextInteger(0, steps)
	return normalized.Min + picked * stepValue
end

local function resolveEnemyRange(biome: string, markerConfig: EnemyMarkerConfig?): BiomeLevelRange
	local fallback = Settings.Enemy.BiomeLevelRanges[biome] or Settings.Enemy.DefaultLevelRange
	local resolved = {
		Min = fallback.Min,
		Max = fallback.Max,
		Step = fallback.Step,
	}
	if markerConfig then
		if type(markerConfig.LevelMin) == "number" then
			resolved.Min = markerConfig.LevelMin
		end
		if type(markerConfig.LevelMax) == "number" then
			resolved.Max = markerConfig.LevelMax
		end
		if type(markerConfig.LevelStep) == "number" then
			resolved.Step = markerConfig.LevelStep
		end
	end
	return normalizeLevelRange(resolved)
end

local function resolveEnemyPath(markerConfig: EnemyMarkerConfig?, rng: Random): string?
	if markerConfig and type(markerConfig.EnemyPath) == "string" and markerConfig.EnemyPath ~= "" then
		return markerConfig.EnemyPath
	end

	local poolId = Settings.Enemy.DefaultPoolId
	if markerConfig and type(markerConfig.PoolId) == "string" and markerConfig.PoolId ~= "" then
		poolId = markerConfig.PoolId
	end

	local pool = Settings.Enemy.Pools[poolId]
	if not pool then
		return nil
	end

	return chooseWeightedEnemyPath(pool, rng)
end

local function chooseWeightedStackReward(options: { StackReward }, rng: Random): StackReward?
	if #options <= 0 then
		return nil
	end

	local weights = {}
	for _, option in ipairs(options) do
		table.insert(weights, option.Weight or 1)
	end
	local chosenIndex = chooseWeightedIndex(weights, rng)
	if not chosenIndex then
		return nil
	end
	return options[chosenIndex]
end

local function chooseWeightedWeapon(options: { WorldSpawnSettings.WeaponReward }, rng: Random): string?
	if #options <= 0 then
		return nil
	end

	local weights = {}
	for _, option in ipairs(options) do
		table.insert(weights, option.Weight or 1)
	end
	local chosenIndex = chooseWeightedIndex(weights, rng)
	if not chosenIndex then
		return nil
	end

	local selected = options[chosenIndex]
	if type(selected.WeaponPath) ~= "string" or selected.WeaponPath == "" then
		return nil
	end
	return selected.WeaponPath
end

local function rollQuantity(minValue: number, maxValue: number, rng: Random): number
	local floorMin = math.max(0, math.floor(minValue))
	local floorMax = math.max(floorMin, math.floor(maxValue))
	return rng:NextInteger(floorMin, floorMax)
end

local function cloneData(data: { [string]: any }?): { [string]: any }?
	if not data then
		return nil
	end
	local clone = {}
	for key, value in pairs(data) do
		clone[key] = value
	end
	return clone
end

local function rollTreasureLoot(lootTableId: string, rng: Random): TreasureGeneratedData?
	local lootTable = Settings.Treasure.LootTables[lootTableId]
	if not lootTable then
		return nil
	end

	local grants = {} :: { TreasureStackGrant }
	local weaponGrants = {} :: { string }

	local function appendStackGrant(definition: StackReward, quantity: number)
		if quantity <= 0 then
			return
		end
		local key = string.format("%s|%s", definition.ItemKind, definition.StackKey)
		for _, existing in ipairs(grants) do
			local existingKey = string.format("%s|%s", existing.ItemKind, existing.StackKey)
			if existingKey == key then
				existing.Quantity += quantity
				return
			end
		end
		table.insert(grants, {
			ItemKind = definition.ItemKind,
			StackKey = definition.StackKey,
			Quantity = quantity,
			MaxStack = definition.MaxStack,
			Data = cloneData(definition.Data),
		})
	end

	local currencyReward = lootTable.CurrencyReward
	if currencyReward then
		appendStackGrant(currencyReward, rollQuantity(currencyReward.Min, currencyReward.Max, rng))
	end

	local stackRewards = lootTable.StackRewards
	local stackRolls = math.max(0, math.floor(lootTable.StackRewardRolls or 0))
	if stackRewards and #stackRewards > 0 and stackRolls > 0 then
		for _ = 1, stackRolls do
			local reward = chooseWeightedStackReward(stackRewards, rng)
			if reward then
				appendStackGrant(reward, rollQuantity(reward.Min, reward.Max, rng))
			end
		end
	end

	local weaponRewards = lootTable.WeaponRewards
	local weaponRolls = math.max(0, math.floor(lootTable.WeaponRolls or 0))
	if weaponRewards and #weaponRewards > 0 and weaponRolls > 0 then
		for _ = 1, weaponRolls do
			local weaponPath = chooseWeightedWeapon(weaponRewards, rng)
			if weaponPath then
				table.insert(weaponGrants, weaponPath)
			end
		end
	end

	return {
		LootTableId = lootTableId,
		StackGrants = grants,
		WeaponGrants = weaponGrants,
	}
end

local function shouldEnableEnemyMarker(markerConfig: EnemyMarkerConfig?): boolean
	if not Settings.Enabled or not Settings.Enemy.Enabled then
		return false
	end
	if markerConfig and markerConfig.Enabled == false then
		return false
	end
	return true
end

local function shouldEnableTreasureMarker(markerConfig: TreasureMarkerConfig?): boolean
	if not Settings.Enabled or not Settings.Treasure.Enabled then
		return false
	end
	if markerConfig and markerConfig.Enabled == false then
		return false
	end
	return true
end

local function makeSpawnPointId(
	seed: number,
	columnX: number,
	columnZ: number,
	prefabId: string,
	markerId: string,
	markerIndex: number
): string
	return string.format("%d:%d:%d:%s:%s:%d", seed, columnX, columnZ, prefabId, markerId, markerIndex)
end

local function logVerbose(message: string)
	if Settings.Debug.Verbose then
		print("[WorldSpawn] " .. message)
	end
end

local function ensureSpawnRoot()
	if SpawnRoot and SpawnRoot.Parent and TreasureRoot and TreasureRoot.Parent then
		return
	end

	local worldRoot = Workspace:FindFirstChild("WorldService")
	if not worldRoot then
		local folder = Instance.new("Folder")
		folder.Name = "WorldService"
		folder.Parent = Workspace
		worldRoot = folder
	end

	local runtimeRoot = worldRoot:FindFirstChild("RuntimeSpawns")
	if runtimeRoot and not runtimeRoot:IsA("Folder") then
		runtimeRoot:Destroy()
		runtimeRoot = nil
	end
	if not runtimeRoot then
		runtimeRoot = Instance.new("Folder")
		runtimeRoot.Name = "RuntimeSpawns"
		runtimeRoot.Parent = worldRoot
	end

	local treasures = runtimeRoot:FindFirstChild("Treasure")
	if treasures and not treasures:IsA("Folder") then
		treasures:Destroy()
		treasures = nil
	end
	if not treasures then
		treasures = Instance.new("Folder")
		treasures.Name = "Treasure"
		treasures.Parent = runtimeRoot
	end

	local debugFolder = runtimeRoot:FindFirstChild("Debug")
	if debugFolder and not debugFolder:IsA("Folder") then
		debugFolder:Destroy()
		debugFolder = nil
	end
	if not debugFolder then
		debugFolder = Instance.new("Folder")
		debugFolder.Name = "Debug"
		debugFolder.Parent = runtimeRoot
	end

	SpawnRoot = runtimeRoot :: Folder
	TreasureRoot = treasures :: Folder
	DebugRoot = debugFolder :: Folder
end

local function clearDebugRoot()
	if not DebugRoot then
		return
	end
	for _, child in ipairs(DebugRoot:GetChildren()) do
		child:Destroy()
	end
end

local function disconnectPrompt(state: SpawnPointState)
	if state.PromptConnection then
		state.PromptConnection:Disconnect()
		state.PromptConnection = nil
	end
end

local function destroyTreasureModel(state: SpawnPointState)
	disconnectPrompt(state)
	if state.ActiveTreasureModel then
		state.ActiveTreasureModel:Destroy()
		state.ActiveTreasureModel = nil
	end
end

local function releaseSpawnPoint(state: SpawnPointState)
	if state.ActiveEnemyUUID then
		EnemyServiceServer.Despawn(state.ActiveEnemyUUID)
		state.ActiveEnemyUUID = nil
	end
	destroyTreasureModel(state)
	if state.Status == "Active" then
		state.Status = "Dormant"
	end
end

local function clearAllRuntimeEntities()
	for _, state in pairs(SpawnPointsById) do
		releaseSpawnPoint(state)
	end
end

local function grantTreasureLoot(player: Player, treasureData: TreasureGeneratedData)
	for _, grant in ipairs(treasureData.StackGrants) do
		if grant.Quantity > 0 then
			InventoryServiceServer.AddStackableItem(
				player,
				grant.ItemKind,
				grant.StackKey,
				grant.Data or {},
				grant.Quantity,
				grant.MaxStack
			)
		end
	end

	for _, weaponPath in ipairs(treasureData.WeaponGrants) do
		local ok, result = pcall(function()
			return InventoryServiceServer.AddWeaponFromPath(player, weaponPath)
		end)
		if not ok then
			warn(string.format("[WorldSpawn] Failed to grant weapon '%s': %s", weaponPath, tostring(result)))
		end
	end
end

local function createDebugAnchor(state: SpawnPointState)
	if not Settings.Debug.ShowSpawnAnchors or not DebugRoot then
		return
	end

	local part = Instance.new("Part")
	part.Name = string.format("%s_%s", state.Type, state.Id)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 0.55
	part.Material = Enum.Material.Neon
	part.Color = if state.Type == "Enemy" then Color3.fromRGB(255, 96, 96) else Color3.fromRGB(255, 216, 96)
	part.Size = if state.Type == "Enemy" then Vector3.new(2, 2, 2) else Vector3.new(1.6, 1.6, 1.6)
	part.CFrame = state.CFrame
	part.Parent = DebugRoot
end

local function claimTreasure(spawnId: string, player: Player): boolean
	local state = SpawnPointsById[spawnId]
	if not state or state.Type ~= "Treasure" then
		return false
	end
	if state.GenerationToken ~= ActiveGenerationToken then
		return false
	end
	if state.Status == "Claimed" then
		return false
	end
	if not state.TreasureData then
		return false
	end

	grantTreasureLoot(player, state.TreasureData)
	state.Status = "Claimed"
	destroyTreasureModel(state)
	logVerbose(string.format("Treasure claimed: %s by %s", spawnId, player.Name))
	return true
end

local function spawnTreasure(state: SpawnPointState)
	if not TreasureRoot then
		return
	end
	if state.ActiveTreasureModel or state.Status == "Claimed" or state.Status == "Dead" then
		return
	end

	local model = Instance.new("Model")
	model.Name = string.format("Treasure_%s", state.Id)
	model:SetAttribute("SpawnId", state.Id)
	model:SetAttribute("PrefabId", state.PrefabId)
	model.Parent = TreasureRoot

	local anchor = Instance.new("Part")
	anchor.Name = "TreasureAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.CFrame = state.CFrame * CFrame.new(0, 1.1, 0)
	anchor.Parent = model

	local beacon = Instance.new("Part")
	beacon.Name = "TreasureBeacon"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.Transparency = 0.35
	beacon.Material = Enum.Material.Neon
	beacon.Color = Color3.fromRGB(255, 212, 108)
	beacon.Size = Vector3.new(0.7, 0.7, 0.7)
	beacon.CFrame = state.CFrame * CFrame.new(0, 2.6, 0)
	beacon.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ClaimPrompt"
	prompt.ActionText = state.PromptActionText or Settings.Treasure.DefaultPrompt.ActionText
	prompt.ObjectText = state.PromptObjectText or Settings.Treasure.DefaultPrompt.ObjectText
	prompt.HoldDuration = Settings.Treasure.DefaultPrompt.HoldDuration
	prompt.MaxActivationDistance = Settings.Treasure.DefaultPrompt.MaxActivationDistance
	prompt.RequiresLineOfSight = Settings.Treasure.DefaultPrompt.RequiresLineOfSight
	prompt.Parent = anchor

	local connection = prompt.Triggered:Connect(function(player)
		claimTreasure(state.Id, player)
	end)

	model.PrimaryPart = anchor
	state.ActiveTreasureModel = model
	state.PromptConnection = connection
	state.Status = "Active"
end

local function buildEnemyGeneratedData(
	biome: string,
	markerConfig: EnemyMarkerConfig?,
	rng: Random
): EnemyGeneratedData?
	local enemyPath = resolveEnemyPath(markerConfig, rng)
	if not enemyPath then
		return nil
	end

	local levelRange = resolveEnemyRange(biome, markerConfig)
	local level = rollLevel(levelRange, rng)
	local lootTableId = if markerConfig and type(markerConfig.LootTableId) == "string" and markerConfig.LootTableId ~= ""
		then markerConfig.LootTableId
		else nil

	return {
		EnemyPath = enemyPath,
		Level = level,
		LootTableId = lootTableId,
	}
end

local function buildTreasureGeneratedData(markerConfig: TreasureMarkerConfig?, rng: Random): TreasureGeneratedData?
	local lootTableId = Settings.Treasure.DefaultLootTableId
	if markerConfig and type(markerConfig.LootTableId) == "string" and markerConfig.LootTableId ~= "" then
		lootTableId = markerConfig.LootTableId
	end

	return rollTreasureLoot(lootTableId, rng)
end

local function spawnEnemy(state: SpawnPointState)
	if state.Status == "Dead" or state.Status == "Claimed" then
		return
	end
	if state.ActiveEnemyUUID then
		return
	end
	if not state.EnemyData then
		return
	end

	local expectedToken = ActiveGenerationToken
	local entity = EnemyServiceServer.Spawn(state.EnemyData.EnemyPath, state.CFrame, state.EnemyData.Level, {
		SpawnContext = {
			SpawnPointId = state.Id,
			PrefabId = state.PrefabId,
			MarkerId = state.MarkerId,
			Biome = state.Biome,
		},
		OnDeath = function(enemyUUID: string, _enemy: Entity)
			local tracked = SpawnPointsById[state.Id]
			if not tracked then
				return
			end
			if tracked.GenerationToken ~= expectedToken or expectedToken ~= ActiveGenerationToken then
				return
			end
			if tracked.ActiveEnemyUUID ~= enemyUUID then
				return
			end
			tracked.ActiveEnemyUUID = nil
			tracked.Status = "Dead"
		end,
	})
	if not entity then
		return
	end

	local uuid = entity.UUID
	state.ActiveEnemyUUID = uuid
	state.Status = "Active"
end

local function activateSpawnPoint(state: SpawnPointState)
	if state.Status == "Claimed" or state.Status == "Dead" then
		return
	end

	if state.Type == "Enemy" then
		spawnEnemy(state)
	elseif state.Type == "Treasure" then
		spawnTreasure(state)
	end
end

local function deactivateSpawnPoint(state: SpawnPointState)
	if state.Type == "Enemy" then
		if not Settings.ChunkLifecycle.DespawnEnemiesOnChunkUnload then
			return
		end
		if state.ActiveEnemyUUID then
			local uuid = state.ActiveEnemyUUID
			EnemyServiceServer.Despawn(uuid)
			state.ActiveEnemyUUID = nil
			if state.Status ~= "Dead" and state.Status ~= "Claimed" then
				state.Status = "Dormant"
			end
		end
	elseif state.Type == "Treasure" then
		if not Settings.ChunkLifecycle.DespawnTreasureOnChunkUnload then
			return
		end
		if state.ActiveTreasureModel then
			destroyTreasureModel(state)
			if state.Status ~= "Dead" and state.Status ~= "Claimed" then
				state.Status = "Dormant"
			end
		end
	end
end

local function activateChunk(chunkId: string)
	local spawnIds = SpawnPointIdsByChunk[chunkId]
	if not spawnIds then
		return
	end

	for _, spawnId in ipairs(spawnIds) do
		local state = SpawnPointsById[spawnId]
		if state and state.GenerationToken == ActiveGenerationToken then
			activateSpawnPoint(state)
		end
	end
end

local function deactivateChunk(chunkId: string)
	local spawnIds = SpawnPointIdsByChunk[chunkId]
	if not spawnIds then
		return
	end

	for _, spawnId in ipairs(spawnIds) do
		local state = SpawnPointsById[spawnId]
		if state and state.GenerationToken == ActiveGenerationToken then
			deactivateSpawnPoint(state)
		end
	end
end

local function getPlayerChunkSet(player: Player): { [string]: boolean }
	local set = PlayerLoadedChunks[player]
	if set then
		return set
	end

	set = {}
	PlayerLoadedChunks[player] = set
	return set
end

local function adjustChunkRef(player: Player, chunkX: number, chunkZ: number, isLoaded: boolean)
	if not Settings.Enabled or not Settings.ChunkLifecycle.Enabled then
		return
	end

	local key = chunkKey(chunkX, chunkZ)
	local loadedSet = getPlayerChunkSet(player)
	local hadChunk = loadedSet[key] == true
	if hadChunk == isLoaded then
		return
	end

	if isLoaded then
		loadedSet[key] = true
		local nextCount = (ChunkRefCounts[key] or 0) + 1
		ChunkRefCounts[key] = nextCount
		if nextCount == 1 then
			activateChunk(key)
		end
	else
		loadedSet[key] = nil
		local nextCount = math.max(0, (ChunkRefCounts[key] or 1) - 1)
		if nextCount <= 0 then
			ChunkRefCounts[key] = nil
			deactivateChunk(key)
		else
			ChunkRefCounts[key] = nextCount
		end
	end
end

function WorldSpawnServiceServer.InitializeWorld(world: WorldState)
	ActiveGenerationToken += 1
	ensureSpawnRoot()
	clearAllRuntimeEntities()
	clearDebugRoot()

	table.clear(SpawnPointsById)
	table.clear(SpawnPointIdsByChunk)
	table.clear(ChunkRefCounts)

	for player, chunkSet in pairs(PlayerLoadedChunks) do
		if player.Parent then
			table.clear(chunkSet)
		else
			PlayerLoadedChunks[player] = nil
		end
	end

	if not Settings.Enabled then
		return
	end

	local tileSize = world.Config.TileSize
	local chunkSize = world.Config.ChunkSize
	local seed = math.max(1, world.Seed)
	local spawnCount = 0

	for _, column in pairs(world.Columns) do
		if not column.Solid or column.StructureTag == nil then
			continue
		end

		local definition = PrefabRegistry.GetById(column.StructureTag)
		if not definition or not definition.SpawnMarkers or #definition.SpawnMarkers <= 0 then
			continue
		end

		local basePosition = Vector3.new(column.X * tileSize, column.SurfaceY, column.Z * tileSize)
		for markerIndex, marker in ipairs(definition.SpawnMarkers :: { PrefabSpawnMarker }) do
			if type(marker.Id) ~= "string" or marker.Id == "" then
				continue
			end
			if marker.Type ~= "Enemy" and marker.Type ~= "Treasure" then
				continue
			end

			local offset = marker.Offset
			local spawnPosition = basePosition + offset
			local yawDeg = if type(marker.YawDegrees) == "number" then marker.YawDegrees else 0
			local spawnCFrame = CFrame.new(spawnPosition) * CFrame.Angles(0, math.rad(yawDeg), 0)
			local markerSeed = hashString(
				string.format("%s:%s:%d", definition.Id, marker.Id, markerIndex),
				foldHash(seed, foldHash(seed, column.X + 8192) + column.Z + 8192)
			)
			local rng = Random.new(math.max(1, markerSeed))
			local markerConfigEnemy = marker.Enemy
			local markerConfigTreasure = marker.Treasure
			local spawnType = marker.Type

			if spawnType == "Enemy" and not shouldEnableEnemyMarker(markerConfigEnemy) then
				continue
			end
			if spawnType == "Treasure" and not shouldEnableTreasureMarker(markerConfigTreasure) then
				continue
			end

			local spawnId = makeSpawnPointId(seed, column.X, column.Z, definition.Id, marker.Id, markerIndex)
			local spawnChunkX = math.floor((spawnPosition.X / tileSize) / chunkSize)
			local spawnChunkZ = math.floor((spawnPosition.Z / tileSize) / chunkSize)
			local state: SpawnPointState = {
				Id = spawnId,
				Type = spawnType,
				Biome = column.Biome,
				ChunkX = spawnChunkX,
				ChunkZ = spawnChunkZ,
				ColumnX = column.X,
				ColumnZ = column.Z,
				PrefabId = definition.Id,
				MarkerId = marker.Id,
				Position = spawnPosition,
				CFrame = spawnCFrame,
				Status = "Dormant",
				EnemyData = nil,
				TreasureData = nil,
				PromptActionText = if markerConfigTreasure then markerConfigTreasure.PromptActionText else nil,
				PromptObjectText = if markerConfigTreasure then markerConfigTreasure.PromptObjectText else nil,
				ActiveEnemyUUID = nil,
				ActiveTreasureModel = nil,
				PromptConnection = nil,
				GenerationToken = ActiveGenerationToken,
			}

			if spawnType == "Enemy" then
				state.EnemyData = buildEnemyGeneratedData(column.Biome, markerConfigEnemy, rng)
				if not state.EnemyData then
					continue
				end
			else
				state.TreasureData = buildTreasureGeneratedData(markerConfigTreasure, rng)
				if not state.TreasureData then
					continue
				end
			end

			SpawnPointsById[spawnId] = state
			local cKey = chunkKey(spawnChunkX, spawnChunkZ)
			local spawnList = SpawnPointIdsByChunk[cKey]
			if not spawnList then
				spawnList = {}
				SpawnPointIdsByChunk[cKey] = spawnList
			end
			table.insert(spawnList, spawnId)
			createDebugAnchor(state)
			spawnCount += 1
		end
	end

	logVerbose(string.format("Initialized %d spawn points for seed %d", spawnCount, seed))
end

function WorldSpawnServiceServer.NotifyChunkLoaded(player: Player, chunkX: number, chunkZ: number)
	adjustChunkRef(player, math.floor(chunkX), math.floor(chunkZ), true)
end

function WorldSpawnServiceServer.NotifyChunkUnloaded(player: Player, chunkX: number, chunkZ: number)
	adjustChunkRef(player, math.floor(chunkX), math.floor(chunkZ), false)
end

function WorldSpawnServiceServer.ClearPlayerChunks(player: Player)
	local loadedSet = PlayerLoadedChunks[player]
	if not loadedSet then
		return
	end

	local keys = {}
	for key in pairs(loadedSet) do
		table.insert(keys, key)
	end
	for _, key in ipairs(keys) do
		local split = string.split(key, ":")
		local chunkX = tonumber(split[1]) or 0
		local chunkZ = tonumber(split[2]) or 0
		adjustChunkRef(player, chunkX, chunkZ, false)
	end

	PlayerLoadedChunks[player] = nil
end

function WorldSpawnServiceServer.ClaimTreasure(spawnId: string, player: Player): boolean
	return claimTreasure(spawnId, player)
end

function WorldSpawnServiceServer.GetSpawnPointCount(): number
	local count = 0
	for _ in pairs(SpawnPointsById) do
		count += 1
	end
	return count
end

Players.PlayerRemoving:Connect(function(player)
	WorldSpawnServiceServer.ClearPlayerChunks(player)
end)

return table.freeze(WorldSpawnServiceServer)
