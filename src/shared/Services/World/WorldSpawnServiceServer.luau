--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PrefabTypes = require(script.Parent.Prefabs.PrefabTypes)
local PrefabRegistry = require(script.Parent.Prefabs.PrefabRegistry)
local PrefabRenderer = require(script.Parent.Prefabs.PrefabRenderer)
local WorldSpawnSettings = require(script.Parent.WorldSpawnSettings)

local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
local InventoryItemRegistry = require(ReplicatedStorage.Database.InventoryItems.Registry)
local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
local ItemDropServiceServer = require(ReplicatedStorage.Services.ItemDrop.ItemDropServiceServer)
local PrefabModels = ReplicatedStorage:WaitForChild("Database"):WaitForChild("PrefabModels")

type PrefabSpawnMarker = PrefabTypes.PrefabSpawnMarker
type EnemyMarkerConfig = PrefabTypes.EnemySpawnMarkerConfig
type TreasureMarkerConfig = PrefabTypes.TreasureSpawnMarkerConfig
type HarvestMarkerConfig = PrefabTypes.HarvestSpawnMarkerConfig
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
	PathRoutes: { { { X: number, Z: number, Height: number, IsIncidentNode: boolean?, IsStructureNode: boolean? } } }?,
	PathEndpoints: { TileColumn }?,
	BossEndpoint: TileColumn?,
}

type EnemyGeneratedData = {
	EnemyPath: string,
	Level: number,
	HealthBonus: number,
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

type HarvestGeneratedData = {
	ItemId: string,
	Quantity: number,
	StackKey: string,
	MaxStack: number,
	SerializedData: { [string]: any },
}

type SpawnGenerationType = "Boss" | "Standard" | "Treasure" | "NoPath"

type SpawnDebugOverrides = {
	EnemyBaseLevel: number?,
	GenerationType: SpawnGenerationType?,
}

type SpawnPointState = {
	Id: string,
	Type: "Enemy" | "Treasure" | "Harvest",
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
	HarvestData: HarvestGeneratedData?,
	PromptActionText: string?,
	PromptObjectText: string?,
	ActiveEnemyUUID: string?,
	ActiveTreasureModel: Model?,
	ActiveHarvestModel: Model?,
	PromptConnection: RBXScriptConnection?,
	GenerationToken: number,
	RequiredItemKind: string?,
	RequiredStackKey: string?,
	RequiredQuantity: number?,
}

local Settings = WorldSpawnSettings :: WorldSpawnSettingsType
local WorldSpawnServiceServer = {}
local endpoint = script.Parent:FindFirstChild("WorldEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "WorldEndpoint"
	endpoint.Parent = script.Parent
end
local WorldEndpoint = endpoint :: RemoteEvent

local SpawnPointsById = {} :: { [string]: SpawnPointState }
local SpawnPointIdsByChunk = {} :: { [string]: { string } }
local ChunkRefCounts = {} :: { [string]: number }
local PlayerLoadedChunks = {} :: { [Player]: { [string]: boolean } }

local SpawnRoot: Folder? = nil
local TreasureRoot: Folder? = nil
local HarvestRoot: Folder? = nil
local DebugRoot: Folder? = nil
local ActiveGenerationToken = 0
local TREASURE_CLAIM_DISTANCE_TOLERANCE = 2
local HARVEST_CLAIM_DISTANCE_TOLERANCE = 2
local GENERATION_TYPE_BOSS: SpawnGenerationType = "Boss"
local GENERATION_TYPE_STANDARD: SpawnGenerationType = "Standard"
local GENERATION_TYPE_TREASURE: SpawnGenerationType = "Treasure"
local GENERATION_TYPE_NO_PATH: SpawnGenerationType = "NoPath"
local DEFAULT_BOSS_POOL_ID = "Camp.Elite"
local RuntimeDebugOverrides = {
	EnemyBaseLevel = nil,
	GenerationType = GENERATION_TYPE_STANDARD,
} :: SpawnDebugOverrides
local DROP_SCATTER_RADIUS = 3.2

local function chunkKey(chunkX: number, chunkZ: number): string
	return tostring(chunkX) .. ":" .. tostring(chunkZ)
end

local function columnKey(columnX: number, columnZ: number): string
	return tostring(columnX) .. ":" .. tostring(columnZ)
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

local function normalizeGenerationType(value: any): SpawnGenerationType
	if value == GENERATION_TYPE_BOSS then
		return GENERATION_TYPE_BOSS
	elseif value == GENERATION_TYPE_STANDARD then
		return GENERATION_TYPE_STANDARD
	elseif value == GENERATION_TYPE_TREASURE then
		return GENERATION_TYPE_TREASURE
	elseif value == GENERATION_TYPE_NO_PATH then
		return GENERATION_TYPE_NO_PATH
	end
	return GENERATION_TYPE_STANDARD
end

local function getGenerationTypeOverride(): SpawnGenerationType
	return normalizeGenerationType(RuntimeDebugOverrides.GenerationType)
end

local function normalizeEnemyBaseLevel(value: any): number?
	if type(value) ~= "number" then
		return nil
	end
	local clamped = math.clamp(math.floor(value), 1, 120)
	return clamped
end

local function getEnemyBaseLevelOverride(): number?
	return normalizeEnemyBaseLevel(RuntimeDebugOverrides.EnemyBaseLevel)
end

local function shouldGenerateEnemiesForType(generationType: SpawnGenerationType): boolean
	return generationType ~= GENERATION_TYPE_TREASURE
end

local function shouldGenerateTreasureForType(generationType: SpawnGenerationType): boolean
	return generationType ~= GENERATION_TYPE_BOSS
end

local function shouldGenerateFallbackPathForType(generationType: SpawnGenerationType): boolean
	return generationType ~= GENERATION_TYPE_NO_PATH and generationType ~= GENERATION_TYPE_TREASURE
end

local function shouldEnableEnemyMarker(markerConfig: EnemyMarkerConfig?): boolean
	if not Settings.Enabled or not Settings.Enemy.Enabled then
		return false
	end
	if not shouldGenerateEnemiesForType(getGenerationTypeOverride()) then
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
	if not shouldGenerateTreasureForType(getGenerationTypeOverride()) then
		return false
	end
	if markerConfig and markerConfig.Enabled == false then
		return false
	end
	return true
end

local function shouldEnableHarvestMarker(markerConfig: HarvestMarkerConfig?): boolean
	if not Settings.Enabled or not Settings.Harvest.Enabled then
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
	if
		SpawnRoot
		and SpawnRoot.Parent
		and TreasureRoot
		and TreasureRoot.Parent
		and HarvestRoot
		and HarvestRoot.Parent
	then
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

	local harvests = runtimeRoot:FindFirstChild("Harvest")
	if harvests and not harvests:IsA("Folder") then
		harvests:Destroy()
		harvests = nil
	end
	if not harvests then
		harvests = Instance.new("Folder")
		harvests.Name = "Harvest"
		harvests.Parent = runtimeRoot
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
	HarvestRoot = harvests :: Folder
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

local function destroyHarvestModel(state: SpawnPointState)
	disconnectPrompt(state)
	if state.ActiveHarvestModel then
		state.ActiveHarvestModel:Destroy()
		state.ActiveHarvestModel = nil
	end
end

local function releaseSpawnPoint(state: SpawnPointState)
	if state.ActiveEnemyUUID then
		EnemyServiceServer.Despawn(state.ActiveEnemyUUID)
		state.ActiveEnemyUUID = nil
	end
	destroyTreasureModel(state)
	destroyHarvestModel(state)
	if state.Status == "Active" then
		state.Status = "Dormant"
	end
end

local function clearAllRuntimeEntities()
	for _, state in pairs(SpawnPointsById) do
		releaseSpawnPoint(state)
	end
end

local function grantTreasureLoot(player: Player, treasureData: TreasureGeneratedData, originPosition: Vector3?)
	local character = player.Character
	local rootPart = nil :: BasePart?
	if character then
		local candidate = character:FindFirstChild("HumanoidRootPart")
		if candidate and candidate:IsA("BasePart") then
			rootPart = candidate
		end
	end
	local dropCenter = originPosition or if rootPart then rootPart.Position else nil
	local dropIndex = 0
	for _, grant in ipairs(treasureData.StackGrants) do
		if grant.Quantity > 0 then
			local normalizedItemKind = if grant.ItemKind == "Item" then "Consumable" else grant.ItemKind
			local shouldDropIntoWorld = normalizedItemKind == "Consumable"
			if shouldDropIntoWorld and dropCenter ~= nil then
				dropIndex += 1
				local angle = (dropIndex / math.max(1, #treasureData.StackGrants)) * math.pi * 2
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * DROP_SCATTER_RADIUS
				ItemDropServiceServer.DropStackGrant(dropCenter + offset, {
					ItemKind = normalizedItemKind,
					StackKey = grant.StackKey,
					Quantity = grant.Quantity,
					MaxStack = grant.MaxStack,
					Data = grant.Data,
				})
			else
				InventoryServiceServer.AddStackableItem(
					player,
					normalizedItemKind,
					grant.StackKey,
					grant.Data or {},
					grant.Quantity,
					grant.MaxStack
				)
			end
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

local function getPlayerRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end
	return nil
end

local function getActiveTreasureAnchor(state: SpawnPointState): BasePart?
	local model = state.ActiveTreasureModel
	if not model or not model.Parent then
		return nil
	end

	local anchor = model:FindFirstChild("TreasureAnchor")
	if anchor and anchor:IsA("BasePart") then
		return anchor
	end

	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return nil
end

local function isTreasureClaimInRange(state: SpawnPointState, player: Player): boolean
	local rootPart = getPlayerRootPart(player)
	if not rootPart then
		return false
	end

	local anchor = getActiveTreasureAnchor(state)
	if not anchor then
		return false
	end

	local maxActivationDistance = Settings.Treasure.DefaultPrompt.MaxActivationDistance
	local claimPrompt = anchor:FindFirstChild("ClaimPrompt")
	if claimPrompt and claimPrompt:IsA("ProximityPrompt") then
		maxActivationDistance = claimPrompt.MaxActivationDistance
	end

	local allowedDistance = math.max(1, maxActivationDistance) + TREASURE_CLAIM_DISTANCE_TOLERANCE
	local distance = (rootPart.Position - anchor.Position).Magnitude
	return distance <= allowedDistance
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
	if state.Status ~= "Active" then
		return false
	end
	if not state.TreasureData then
		return false
	end
	if not isTreasureClaimInRange(state, player) then
		logVerbose(string.format("Rejected treasure claim out of range: %s by %s", spawnId, player.Name))
		return false
	end
	if state.RequiredItemKind and state.RequiredStackKey then
		local requiredQuantity = math.max(1, state.RequiredQuantity or 1)
		if
			not InventoryServiceServer.HasStackQuantity(
				player,
				state.RequiredItemKind,
				state.RequiredStackKey,
				requiredQuantity
			)
		then
			logVerbose(string.format("Rejected treasure claim missing key item: %s by %s", spawnId, player.Name))
			return false
		end
		if
			not InventoryServiceServer.ConsumeStackQuantity(
				player,
				state.RequiredItemKind,
				state.RequiredStackKey,
				requiredQuantity
			)
		then
			return false
		end
	end

	disconnectPrompt(state)
	grantTreasureLoot(player, state.TreasureData, state.Position)
	state.Status = "Claimed"
	WorldEndpoint:FireAllClients("TreasureClaimed", {
		SpawnId = state.Id,
		PrefabId = state.PrefabId,
		ColumnX = state.ColumnX,
		ColumnZ = state.ColumnZ,
		MarkerId = state.MarkerId,
		Position = state.Position,
		ActionText = state.PromptActionText,
		ObjectText = state.PromptObjectText,
		ClaimedByUserId = player.UserId,
	})
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

	if PrefabRegistry.GetById(state.PrefabId) then
		PrefabRenderer.Render(state.PrefabId, model, {
			Position = state.Position,
			TileSize = 1,
			SurfaceY = state.Position.Y,
			Biome = state.Biome,
			ColumnX = state.ColumnX,
			ColumnZ = state.ColumnZ,
			Seed = ActiveGenerationToken,
			NameSuffix = state.Id,
		})
	end

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

local function getActiveHarvestAnchor(state: SpawnPointState): BasePart?
	local model = state.ActiveHarvestModel
	if not model or not model.Parent then
		return nil
	end

	local anchor = model:FindFirstChild("HarvestAnchor")
	if anchor and anchor:IsA("BasePart") then
		return anchor
	end

	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return nil
end

local function isHarvestClaimInRange(state: SpawnPointState, player: Player): boolean
	local rootPart = getPlayerRootPart(player)
	if not rootPart then
		return false
	end

	local anchor = getActiveHarvestAnchor(state)
	if not anchor then
		return false
	end

	local maxActivationDistance = Settings.Harvest.DefaultPrompt.MaxActivationDistance
	local prompt = anchor:FindFirstChild("HarvestPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		maxActivationDistance = prompt.MaxActivationDistance
	end

	local allowedDistance = math.max(1, maxActivationDistance) + HARVEST_CLAIM_DISTANCE_TOLERANCE
	return (rootPart.Position - anchor.Position).Magnitude <= allowedDistance
end

local function claimHarvest(spawnId: string, player: Player): boolean
	local state = SpawnPointsById[spawnId]
	if not state or state.Type ~= "Harvest" then
		return false
	end
	if state.GenerationToken ~= ActiveGenerationToken then
		return false
	end
	if state.Status == "Claimed" or state.Status ~= "Active" then
		return false
	end
	if not state.HarvestData then
		return false
	end
	if not isHarvestClaimInRange(state, player) then
		logVerbose(string.format("Rejected harvest claim out of range: %s by %s", spawnId, player.Name))
		return false
	end

	disconnectPrompt(state)
	InventoryServiceServer.AddStackableItem(
		player,
		"InventoryItem",
		state.HarvestData.StackKey,
		state.HarvestData.SerializedData,
		state.HarvestData.Quantity,
		state.HarvestData.MaxStack
	)
	state.Status = "Claimed"
	WorldEndpoint:FireAllClients("HarvestClaimed", {
		SpawnId = state.Id,
		PrefabId = state.PrefabId,
		ColumnX = state.ColumnX,
		ColumnZ = state.ColumnZ,
		MarkerId = state.MarkerId,
		Position = state.Position,
		ItemId = state.HarvestData.ItemId,
		Quantity = state.HarvestData.Quantity,
	})
	destroyHarvestModel(state)
	logVerbose(string.format("Harvest claimed: %s by %s", spawnId, player.Name))
	return true
end

local function spawnHarvest(state: SpawnPointState)
	if not HarvestRoot then
		return
	end
	if state.ActiveHarvestModel or state.Status == "Claimed" or state.Status == "Dead" then
		return
	end

	local model = Instance.new("Model")
	model.Name = string.format("Harvest_%s", state.Id)
	model:SetAttribute("SpawnId", state.Id)
	model:SetAttribute("PrefabId", state.PrefabId)
	model.Parent = HarvestRoot

	local markerSeed = hashString(state.Id, foldHash(ActiveGenerationToken, state.ColumnX + state.ColumnZ + 16384))
	local visualRng = Random.new(math.max(1, markerSeed))
	local usedDirectModel = tryCloneIncidentPrefabModel(state.PrefabId, model, state.CFrame, visualRng) ~= nil

	if not usedDirectModel and PrefabRegistry.GetById(state.PrefabId) then
		PrefabRenderer.Render(state.PrefabId, model, {
			Position = state.Position,
			TileSize = 1,
			SurfaceY = state.Position.Y,
			Biome = state.Biome,
			ColumnX = state.ColumnX,
			ColumnZ = state.ColumnZ,
			Seed = ActiveGenerationToken,
			NameSuffix = state.Id,
		})
	end

	local anchor = Instance.new("Part")
	anchor.Name = "HarvestAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.CFrame = state.CFrame * CFrame.new(0, 1.2, 0)
	anchor.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = state.PromptActionText or Settings.Harvest.DefaultPrompt.ActionText
	prompt.ObjectText = state.PromptObjectText or Settings.Harvest.DefaultPrompt.ObjectText
	prompt.HoldDuration = Settings.Harvest.DefaultPrompt.HoldDuration
	prompt.MaxActivationDistance = Settings.Harvest.DefaultPrompt.MaxActivationDistance
	prompt.RequiresLineOfSight = Settings.Harvest.DefaultPrompt.RequiresLineOfSight
	prompt.Parent = anchor

	local connection = prompt.Triggered:Connect(function(player)
		claimHarvest(state.Id, player)
	end)

	model.PrimaryPart = anchor
	state.ActiveHarvestModel = model
	state.PromptConnection = connection
	state.Status = "Active"
end

local FALLBACK_PATH_PREFAB_ID = "PathFallback"
local FALLBACK_PATH_MARKER_ID = "Enemy"
local FALLBACK_PATH_MARKER_INDEX = 1
local BOSS_ENDPOINT_PREFAB_ID = "BossEndpoint"
local BOSS_ENDPOINT_MARKER_ID = "BossArena"
local BOSS_ENDPOINT_MARKER_INDEX = 1
local INCIDENT_ANIMAL_PREFAB_ID = "IncidentAnimal"
local INCIDENT_HOSTILE_PREFAB_ID = "IncidentHostile"
local INCIDENT_HARVEST_MARKER_ID = "IncidentHarvest"
local INCIDENT_TREASURE_MARKER_ID = "IncidentTreasure"
local FALLBACK_PATH_MIN_TILE_GAP = 14
local FALLBACK_PATH_SPAWN_ODDS = 0.08
local FALLBACK_PATH_MAX_ENEMIES_PER_CHUNK = 2
local DISTANCE_HEALTH_BONUS_MAX = 5
local INCIDENT_ANIMAL_COUNT = 2
local INCIDENT_ANIMAL_RADIUS_STUDS = 10
local INCIDENT_HOSTILE_RADIUS_STUDS = 12
local INCIDENT_MODEL_ASSETS_BY_PREFAB_ID = {
	["Shared::IncidentBlueberryPatch"] = { "Blueberry" },
	["Shared::IncidentStrawberryPatch"] = { "Strawberry" },
	["Shared::IncidentCactusFruit"] = { "Cactus" },
	["Shared::IncidentWheatPatch"] = { "Farm" },
	["Forest::WildMushroomPatch"] = { "Mushroom1", "Mushroom2", "Mushroom3" },
}

type IncidentHarvestSpec = {
	PrefabId: string,
	ItemId: string,
	QuantityMin: number,
	QuantityMax: number,
	ActionText: string,
	ObjectText: string,
}

type IncidentChestSpec = {
	PrefabId: string,
	LootTableId: string,
	ActionText: string,
	ObjectText: string,
	RequiredItemKind: string?,
	RequiredStackKey: string?,
	RequiredQuantity: number?,
}

local tryCloneIncidentPrefabModel: ((string, Instance, CFrame, Random) -> Model?)? = nil
local function computeDistanceHealthBonus(columnX: number, columnZ: number, radiusTiles: number): number
	local safeRadius = math.max(1, radiusTiles)
	local distance = math.sqrt(columnX * columnX + columnZ * columnZ)
	local normalized = math.clamp(distance / safeRadius, 0, 1)
	local scaled = normalized * DISTANCE_HEALTH_BONUS_MAX
	return math.clamp(math.floor(scaled + 0.5), 0, DISTANCE_HEALTH_BONUS_MAX)
end

local function buildEnemyGeneratedData(
	biome: string,
	columnX: number,
	columnZ: number,
	worldRadiusTiles: number,
	markerConfig: EnemyMarkerConfig?,
	rng: Random,
	forceBoss: boolean?
): EnemyGeneratedData?
	local generationType = getGenerationTypeOverride()
	local enemyPath: string? = nil
	if forceBoss == true then
		local bossPool = Settings.Enemy.Pools[DEFAULT_BOSS_POOL_ID]
		if bossPool then
			enemyPath = chooseWeightedEnemyPath(bossPool, rng)
		end
		if not enemyPath then
			enemyPath = resolveEnemyPath(markerConfig, rng)
		end
	else
		enemyPath = resolveEnemyPath(markerConfig, rng)
	end
	if not enemyPath then
		return nil
	end

	local level = 1
	local lootTableId = if markerConfig
			and type(markerConfig.LootTableId) == "string"
			and markerConfig.LootTableId ~= ""
		then markerConfig.LootTableId
		else nil

	return {
		EnemyPath = enemyPath,
		Level = level,
		HealthBonus = computeDistanceHealthBonus(columnX, columnZ, worldRadiusTiles),
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

local function buildTreasureGeneratedDataForLootTableId(lootTableId: string, rng: Random): TreasureGeneratedData?
	if type(lootTableId) ~= "string" or lootTableId == "" then
		return nil
	end
	return rollTreasureLoot(lootTableId, rng)
end

local function buildHarvestSerializedData(itemId: string): { any }?
	local definition = InventoryItemRegistry.Get(itemId)
	if not definition then
		return nil
	end

	return {
		Kind = "Item",
		ItemId = definition.Id,
		Name = definition.Name,
		Desc = definition.Desc,
		Icon = definition.Icon,
		MaxStack = definition.MaxStack,
		SpawnWith = definition.SpawnWith,
		StackKey = "InventoryItem:" .. definition.Id,
		CanEquip = definition.CanEquip,
		CanUse = definition.CanUse,
		EquipSlotType = definition.EquipSlotType,
		ModelAssetName = definition.ModelAssetName,
		InventoryData = cloneData(definition.InventoryData) or {},
		UseEffects = cloneData(definition.UseEffects) or {},
	},
		definition.MaxStack,
		"InventoryItem:" .. definition.Id
end

local function buildHarvestGeneratedData(markerConfig: HarvestMarkerConfig?, rng: Random): HarvestGeneratedData?
	if not markerConfig or type(markerConfig.ItemId) ~= "string" or markerConfig.ItemId == "" then
		return nil
	end

	local serializedData, maxStack, stackKey = buildHarvestSerializedData(markerConfig.ItemId)
	if not serializedData then
		return nil
	end

	local quantityMin = if type(markerConfig.QuantityMin) == "number" then markerConfig.QuantityMin else 1
	local quantityMax = if type(markerConfig.QuantityMax) == "number" then markerConfig.QuantityMax else quantityMin
	local quantity = rollQuantity(quantityMin, quantityMax, rng)
	if quantity <= 0 then
		return nil
	end

	return {
		ItemId = markerConfig.ItemId,
		Quantity = quantity,
		StackKey = stackKey,
		MaxStack = maxStack,
		SerializedData = serializedData,
	}
end

local function buildHarvestGeneratedDataForItem(
	itemId: string,
	quantityMin: number,
	quantityMax: number,
	rng: Random
): HarvestGeneratedData?
	return buildHarvestGeneratedData({
		ItemId = itemId,
		QuantityMin = quantityMin,
		QuantityMax = quantityMax,
	}, rng)
end

local function chooseIncidentAnimalEnemyPath(biome: string): string?
	if biome == "Plains" then
		return "Animals.Cow"
	elseif biome == "Forest" then
		return "Animals.Chicken"
	elseif biome == "Tundra" or biome == "Mountain" then
		return "Animals.Sheep"
	end
	return nil
end

local function chooseIncidentHarvestSpec(biome: string, rng: Random): IncidentHarvestSpec?
	if biome == "Plains" then
		return {
			PrefabId = "Shared::IncidentWheatPatch",
			ItemId = "Wheat",
			QuantityMin = 2,
			QuantityMax = 4,
			ActionText = "Harvest",
			ObjectText = "Wild Wheat",
		}
	elseif biome == "Forest" then
		return {
			PrefabId = "Forest::WildMushroomPatch",
			ItemId = "Mushroom",
			QuantityMin = 1,
			QuantityMax = 3,
			ActionText = "Gather",
			ObjectText = "Foraged Mushrooms",
		}
	elseif biome == "Desert" then
		return {
			PrefabId = "Shared::IncidentCactusFruit",
			ItemId = "CactusFruit",
			QuantityMin = 1,
			QuantityMax = 3,
			ActionText = "Pick",
			ObjectText = "Cactus Fruit",
		}
	elseif biome == "Tundra" then
		if rng:NextNumber() < 0.5 then
			return {
				PrefabId = "Shared::IncidentBlueberryPatch",
				ItemId = "Blueberry",
				QuantityMin = 2,
				QuantityMax = 4,
				ActionText = "Pick",
				ObjectText = "Blueberries",
			}
		end
		return {
			PrefabId = "Shared::IncidentStrawberryPatch",
			ItemId = "Strawberry",
			QuantityMin = 2,
			QuantityMax = 4,
			ActionText = "Pick",
			ObjectText = "Wild Strawberries",
		}
	end
	return nil
end

local function chooseIncidentHostilePack(rng: Random): { string }
	local roll = rng:NextNumber()
	if roll < 0.4 then
		return { "ROBLOX.Noob", "ROBLOX.Noob", "ROBLOX.Noob" }
	elseif roll < 0.6 then
		return { "ROBLOX.Noob", "ROBLOX.Noob", "ROBLOX.Noob", "ROBLOX.Noob", "ROBLOX.Noob" }
	elseif roll < 0.75 then
		return { "ROBLOX.Guest", "ROBLOX.Guest", "ROBLOX.Guest", "ROBLOX.Guest" }
	elseif roll < 0.9 then
		return { "ROBLOX.Guest", "ROBLOX.Guest", "ROBLOX.Noob", "ROBLOX.Noob", "ROBLOX.Noob" }
	elseif roll < 0.96 then
		return { "ROBLOX.Builder" }
	end
	return { "ROBLOX.Bacon", "ROBLOX.Bacon", "ROBLOX.Bacon", "ROBLOX.Bacon" }
end

local function chooseIncidentChestSpec(rng: Random): IncidentChestSpec
	if rng:NextNumber() < 0.75 then
		return {
			PrefabId = "Shared::TreasureChestFieldCache",
			LootTableId = "FieldCache",
			ActionText = "Open Cache",
			ObjectText = "Weathered Cache",
			RequiredItemKind = nil,
			RequiredStackKey = nil,
			RequiredQuantity = nil,
		}
	end
	return {
		PrefabId = "Shared::TreasureChestCache",
		LootTableId = "RelicCache",
		ActionText = "Unlock",
		ObjectText = "Sealed Reliquary",
		RequiredItemKind = "InventoryItem",
		RequiredStackKey = "InventoryItem:ChestKey",
		RequiredQuantity = 1,
	}
end

local function getIncidentOffset(positionIndex: number, total: number, radiusStuds: number): Vector3
	if total <= 1 then
		return Vector3.zero
	end
	local angle = ((positionIndex - 1) / total) * math.pi * 2
	return Vector3.new(math.cos(angle) * radiusStuds, 0, math.sin(angle) * radiusStuds)
end

local function markModelAsHarvestVisual(model: Model, destroyMode: string)
	model:SetAttribute("HarvestVisualMode", destroyMode)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant:SetAttribute("HarvestVisual", true)
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

function tryCloneIncidentPrefabModel(prefabId: string, parent: Instance, cframe: CFrame, rng: Random): Model?
	local assetNames = INCIDENT_MODEL_ASSETS_BY_PREFAB_ID[prefabId]
	if not assetNames or #assetNames <= 0 then
		return nil
	end

	local assetName = assetNames[math.clamp(rng:NextInteger(1, #assetNames), 1, #assetNames)]
	local template = PrefabModels:FindFirstChild(assetName)
	if not template then
		return nil
	end

	local clone = template:Clone()
	local model: Model
	if clone:IsA("Model") then
		model = clone
	else
		model = Instance.new("Model")
		model.Name = assetName
		clone.Parent = model
	end

	if string.find(assetName, "Mushroom", 1, true) then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant ~= model and descendant.Name == "Mushroom" then
				descendant:Destroy()
			end
		end
	end

	model.Name = string.format("%s_%s", assetName, tostring(rng:NextInteger(1000, 9999)))
	model.Parent = parent
	pcall(function()
		model:PivotTo(cframe)
	end)
	markModelAsHarvestVisual(model, "DestroyPrefab")
	return model
end

local function shouldCreateFallbackPathSpawn(seed: number, column: TileColumn): boolean
	if not column.Solid or not column.IsPath then
		return false
	end

	local spacing = math.abs(column.X) % FALLBACK_PATH_MIN_TILE_GAP == 0
		or math.abs(column.Z) % FALLBACK_PATH_MIN_TILE_GAP == 0
	if not spacing then
		return false
	end

	local rollSeed = foldHash(seed, foldHash(seed, column.X + 4096) + column.Z + 4096)
	local rng = Random.new(math.max(1, rollSeed))
	return rng:NextNumber() <= FALLBACK_PATH_SPAWN_ODDS
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
			HealthBonus = state.EnemyData.HealthBonus,
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
	elseif state.Type == "Harvest" then
		spawnHarvest(state)
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
	elseif state.Type == "Harvest" then
		if state.ActiveHarvestModel then
			destroyHarvestModel(state)
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

local function registerSpawnState(state: SpawnPointState)
	SpawnPointsById[state.Id] = state
	local cKey = chunkKey(state.ChunkX, state.ChunkZ)
	local spawnList = SpawnPointIdsByChunk[cKey]
	if not spawnList then
		spawnList = {}
		SpawnPointIdsByChunk[cKey] = spawnList
	end
	table.insert(spawnList, state.Id)
	createDebugAnchor(state)
end

local function unregisterSpawnState(state: SpawnPointState)
	local cKey = chunkKey(state.ChunkX, state.ChunkZ)
	local spawnList = SpawnPointIdsByChunk[cKey]
	if spawnList then
		local nextSpawnList = {} :: { string }
		for _, spawnId in ipairs(spawnList) do
			if spawnId ~= state.Id then
				table.insert(nextSpawnList, spawnId)
			end
		end
		if #nextSpawnList > 0 then
			SpawnPointIdsByChunk[cKey] = nextSpawnList
		else
			SpawnPointIdsByChunk[cKey] = nil
		end
	end

	SpawnPointsById[state.Id] = nil
end

local function rebuildDebugAnchors()
	clearDebugRoot()
	for _, state in pairs(SpawnPointsById) do
		createDebugAnchor(state)
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
	local fallbackEnemyCountByChunk = {} :: { [string]: number }

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
			if marker.Type ~= "Enemy" and marker.Type ~= "Treasure" and marker.Type ~= "Harvest" then
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
			local markerConfigHarvest = marker.Harvest
			local spawnType = marker.Type

			if spawnType == "Enemy" and not shouldEnableEnemyMarker(markerConfigEnemy) then
				continue
			end
			if spawnType == "Treasure" and not shouldEnableTreasureMarker(markerConfigTreasure) then
				continue
			end
			if spawnType == "Harvest" and not shouldEnableHarvestMarker(markerConfigHarvest) then
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
				HarvestData = nil,
				PromptActionText = if markerConfigTreasure then markerConfigTreasure.PromptActionText else nil,
				PromptObjectText = if markerConfigTreasure then markerConfigTreasure.PromptObjectText else nil,
				ActiveEnemyUUID = nil,
				ActiveTreasureModel = nil,
				ActiveHarvestModel = nil,
				PromptConnection = nil,
				GenerationToken = ActiveGenerationToken,
			}

			if spawnType == "Enemy" then
				state.EnemyData = buildEnemyGeneratedData(
					column.Biome,
					column.X,
					column.Z,
					world.Config.RadiusTiles,
					markerConfigEnemy,
					rng,
					false
				)
				if not state.EnemyData then
					continue
				end
			elseif spawnType == "Treasure" then
				state.TreasureData = buildTreasureGeneratedData(markerConfigTreasure, rng)
				if not state.TreasureData then
					continue
				end
			else
				state.HarvestData = buildHarvestGeneratedData(markerConfigHarvest, rng)
				state.PromptActionText = if markerConfigHarvest then markerConfigHarvest.PromptActionText else nil
				state.PromptObjectText = if markerConfigHarvest then markerConfigHarvest.PromptObjectText else nil
				if not state.HarvestData then
					continue
				end
			end

			registerSpawnState(state)
			spawnCount += 1
		end
	end

	if world.PathRoutes then
		local incidentNodeIndex = 0
		for _, route in ipairs(world.PathRoutes) do
			if #route ~= 1 then
				continue
			end
			local node = route[1]
			if node.IsIncidentNode ~= true or node.IsStructureNode == true then
				continue
			end

			local column = world.Columns[string.format("%d:%d", node.X, node.Z)]
			if not column or not column.Solid then
				continue
			end

			incidentNodeIndex += 1
			local markerSeed = hashString(
				string.format("Incident:%d:%d:%d", incidentNodeIndex, node.X, node.Z),
				foldHash(seed, foldHash(seed, node.X + 8192) + node.Z + 8192)
			)
			local rng = Random.new(math.max(1, markerSeed))
			local incidentRoll = rng:NextNumber()
			local centerPosition = Vector3.new(column.X * tileSize, column.SurfaceY, column.Z * tileSize)
			local spawnChunkX = math.floor(column.X / chunkSize)
			local spawnChunkZ = math.floor(column.Z / chunkSize)

			if incidentRoll < 0.6 then
				local harvestSpec = chooseIncidentHarvestSpec(column.Biome, rng)
				if harvestSpec then
					local harvestData = buildHarvestGeneratedDataForItem(
						harvestSpec.ItemId,
						harvestSpec.QuantityMin,
						harvestSpec.QuantityMax,
						rng
					)
					if harvestData then
						registerSpawnState({
							Id = makeSpawnPointId(
								seed,
								column.X,
								column.Z,
								harvestSpec.PrefabId,
								INCIDENT_HARVEST_MARKER_ID,
								incidentNodeIndex
							),
							Type = "Harvest",
							Biome = column.Biome,
							ChunkX = spawnChunkX,
							ChunkZ = spawnChunkZ,
							ColumnX = column.X,
							ColumnZ = column.Z,
							PrefabId = harvestSpec.PrefabId,
							MarkerId = INCIDENT_HARVEST_MARKER_ID,
							Position = centerPosition,
							CFrame = CFrame.new(centerPosition),
							Status = "Dormant",
							EnemyData = nil,
							TreasureData = nil,
							HarvestData = harvestData,
							PromptActionText = harvestSpec.ActionText,
							PromptObjectText = harvestSpec.ObjectText,
							ActiveEnemyUUID = nil,
							ActiveTreasureModel = nil,
							ActiveHarvestModel = nil,
							PromptConnection = nil,
							GenerationToken = ActiveGenerationToken,
							RequiredItemKind = nil,
							RequiredStackKey = nil,
							RequiredQuantity = nil,
						})
						spawnCount += 1
					end
				end

				local animalEnemyPath = chooseIncidentAnimalEnemyPath(column.Biome)
				if animalEnemyPath then
					for animalIndex = 1, INCIDENT_ANIMAL_COUNT do
						local enemyData = buildEnemyGeneratedData(
							column.Biome,
							column.X,
							column.Z,
							world.Config.RadiusTiles,
							{ EnemyPath = animalEnemyPath },
							rng,
							false
						)
						if enemyData then
							local offset = getIncidentOffset(animalIndex, INCIDENT_ANIMAL_COUNT, INCIDENT_ANIMAL_RADIUS_STUDS)
							local spawnPosition = centerPosition + offset
							registerSpawnState({
								Id = makeSpawnPointId(
									seed,
									column.X,
									column.Z,
									INCIDENT_ANIMAL_PREFAB_ID,
									animalEnemyPath,
									incidentNodeIndex * 10 + animalIndex
								),
								Type = "Enemy",
								Biome = column.Biome,
								ChunkX = spawnChunkX,
								ChunkZ = spawnChunkZ,
								ColumnX = column.X,
								ColumnZ = column.Z,
								PrefabId = INCIDENT_ANIMAL_PREFAB_ID,
								MarkerId = animalEnemyPath,
								Position = spawnPosition,
								CFrame = CFrame.new(spawnPosition),
								Status = "Dormant",
								EnemyData = enemyData,
								TreasureData = nil,
								HarvestData = nil,
								PromptActionText = nil,
								PromptObjectText = nil,
								ActiveEnemyUUID = nil,
								ActiveTreasureModel = nil,
								ActiveHarvestModel = nil,
								PromptConnection = nil,
								GenerationToken = ActiveGenerationToken,
								RequiredItemKind = nil,
								RequiredStackKey = nil,
								RequiredQuantity = nil,
							})
							spawnCount += 1
						end
					end
				end
			elseif incidentRoll < 0.9 then
				local enemyPack = chooseIncidentHostilePack(rng)
				for enemyIndex, enemyPath in ipairs(enemyPack) do
					local enemyData = buildEnemyGeneratedData(
						column.Biome,
						column.X,
						column.Z,
						world.Config.RadiusTiles,
						{ EnemyPath = enemyPath },
						rng,
						false
					)
					if enemyData then
						local offset = getIncidentOffset(enemyIndex, #enemyPack, INCIDENT_HOSTILE_RADIUS_STUDS)
						local spawnPosition = centerPosition + offset
						registerSpawnState({
							Id = makeSpawnPointId(
								seed,
								column.X,
								column.Z,
								INCIDENT_HOSTILE_PREFAB_ID,
								enemyPath,
								incidentNodeIndex * 20 + enemyIndex
							),
							Type = "Enemy",
							Biome = column.Biome,
							ChunkX = spawnChunkX,
							ChunkZ = spawnChunkZ,
							ColumnX = column.X,
							ColumnZ = column.Z,
							PrefabId = INCIDENT_HOSTILE_PREFAB_ID,
							MarkerId = enemyPath,
							Position = spawnPosition,
							CFrame = CFrame.new(spawnPosition),
							Status = "Dormant",
							EnemyData = enemyData,
							TreasureData = nil,
							HarvestData = nil,
							PromptActionText = nil,
							PromptObjectText = nil,
							ActiveEnemyUUID = nil,
							ActiveTreasureModel = nil,
							ActiveHarvestModel = nil,
							PromptConnection = nil,
							GenerationToken = ActiveGenerationToken,
							RequiredItemKind = nil,
							RequiredStackKey = nil,
							RequiredQuantity = nil,
						})
						spawnCount += 1
					end
				end
			else
				local chestSpec = chooseIncidentChestSpec(rng)
				local treasureData = buildTreasureGeneratedDataForLootTableId(chestSpec.LootTableId, rng)
				if treasureData then
					registerSpawnState({
						Id = makeSpawnPointId(
							seed,
							column.X,
							column.Z,
							chestSpec.PrefabId,
							INCIDENT_TREASURE_MARKER_ID,
							incidentNodeIndex
						),
						Type = "Treasure",
						Biome = column.Biome,
						ChunkX = spawnChunkX,
						ChunkZ = spawnChunkZ,
						ColumnX = column.X,
						ColumnZ = column.Z,
						PrefabId = chestSpec.PrefabId,
						MarkerId = INCIDENT_TREASURE_MARKER_ID,
						Position = centerPosition,
						CFrame = CFrame.new(centerPosition),
						Status = "Dormant",
						EnemyData = nil,
						TreasureData = treasureData,
						HarvestData = nil,
						PromptActionText = chestSpec.ActionText,
						PromptObjectText = chestSpec.ObjectText,
						ActiveEnemyUUID = nil,
						ActiveTreasureModel = nil,
						ActiveHarvestModel = nil,
						PromptConnection = nil,
						GenerationToken = ActiveGenerationToken,
						RequiredItemKind = chestSpec.RequiredItemKind,
						RequiredStackKey = chestSpec.RequiredStackKey,
						RequiredQuantity = chestSpec.RequiredQuantity,
					})
					spawnCount += 1
				end
			end
		end
	end

	if shouldGenerateFallbackPathForType(getGenerationTypeOverride()) then
		for _, column in pairs(world.Columns) do
			if not shouldCreateFallbackPathSpawn(seed, column) then
				continue
			end

			local spawnChunkX = math.floor(column.X / chunkSize)
			local spawnChunkZ = math.floor(column.Z / chunkSize)
			local cKey = chunkKey(spawnChunkX, spawnChunkZ)
			local existingCount = fallbackEnemyCountByChunk[cKey] or 0
			if existingCount >= FALLBACK_PATH_MAX_ENEMIES_PER_CHUNK then
				continue
			end

			local markerSeed = hashString(
				string.format("%s:%s:%d", FALLBACK_PATH_PREFAB_ID, FALLBACK_PATH_MARKER_ID, FALLBACK_PATH_MARKER_INDEX),
				foldHash(seed, foldHash(seed, column.X + 8192) + column.Z + 8192)
			)
			local rng = Random.new(math.max(1, markerSeed))
			local enemyData =
				buildEnemyGeneratedData(column.Biome, column.X, column.Z, world.Config.RadiusTiles, nil, rng, false)
			if not enemyData then
				continue
			end

			local spawnPosition = Vector3.new(column.X * tileSize, column.SurfaceY, column.Z * tileSize)
			local spawnId = makeSpawnPointId(
				seed,
				column.X,
				column.Z,
				FALLBACK_PATH_PREFAB_ID,
				FALLBACK_PATH_MARKER_ID,
				FALLBACK_PATH_MARKER_INDEX
			)
			local state: SpawnPointState = {
				Id = spawnId,
				Type = "Enemy",
				Biome = column.Biome,
				ChunkX = spawnChunkX,
				ChunkZ = spawnChunkZ,
				ColumnX = column.X,
				ColumnZ = column.Z,
				PrefabId = FALLBACK_PATH_PREFAB_ID,
				MarkerId = FALLBACK_PATH_MARKER_ID,
				Position = spawnPosition,
				CFrame = CFrame.new(spawnPosition),
				Status = "Dormant",
				EnemyData = enemyData,
				TreasureData = nil,
				HarvestData = nil,
				PromptActionText = nil,
				PromptObjectText = nil,
				ActiveEnemyUUID = nil,
				ActiveTreasureModel = nil,
				ActiveHarvestModel = nil,
				PromptConnection = nil,
				GenerationToken = ActiveGenerationToken,
				RequiredItemKind = nil,
				RequiredStackKey = nil,
				RequiredQuantity = nil,
			}

			registerSpawnState(state)
			fallbackEnemyCountByChunk[cKey] = existingCount + 1
			spawnCount += 1
		end
	end

	if getGenerationTypeOverride() == GENERATION_TYPE_BOSS and world.BossEndpoint then
		local column = world.BossEndpoint
		local spawnChunkX = math.floor(column.X / chunkSize)
		local spawnChunkZ = math.floor(column.Z / chunkSize)
		local markerSeed = hashString(
			string.format("%s:%s:%d", BOSS_ENDPOINT_PREFAB_ID, BOSS_ENDPOINT_MARKER_ID, BOSS_ENDPOINT_MARKER_INDEX),
			foldHash(seed, foldHash(seed, column.X + 8192) + column.Z + 8192)
		)
		local rng = Random.new(math.max(1, markerSeed))
		local enemyData =
			buildEnemyGeneratedData(column.Biome, column.X, column.Z, world.Config.RadiusTiles, nil, rng, true)
		if enemyData then
			local spawnPosition = Vector3.new(column.X * tileSize, column.SurfaceY, column.Z * tileSize)
			local spawnId = makeSpawnPointId(
				seed,
				column.X,
				column.Z,
				BOSS_ENDPOINT_PREFAB_ID,
				BOSS_ENDPOINT_MARKER_ID,
				BOSS_ENDPOINT_MARKER_INDEX
			)
			local cKey = chunkKey(spawnChunkX, spawnChunkZ)
			local state: SpawnPointState = {
				Id = spawnId,
				Type = "Enemy",
				Biome = column.Biome,
				ChunkX = spawnChunkX,
				ChunkZ = spawnChunkZ,
				ColumnX = column.X,
				ColumnZ = column.Z,
				PrefabId = BOSS_ENDPOINT_PREFAB_ID,
				MarkerId = BOSS_ENDPOINT_MARKER_ID,
				Position = spawnPosition,
				CFrame = CFrame.new(spawnPosition),
				Status = "Dormant",
				EnemyData = enemyData,
				TreasureData = nil,
				HarvestData = nil,
				PromptActionText = nil,
				PromptObjectText = nil,
				ActiveEnemyUUID = nil,
				ActiveTreasureModel = nil,
				ActiveHarvestModel = nil,
				PromptConnection = nil,
				GenerationToken = ActiveGenerationToken,
				RequiredItemKind = nil,
				RequiredStackKey = nil,
				RequiredQuantity = nil,
			}
			registerSpawnState(state)
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

function WorldSpawnServiceServer.GetClaimedHarvests(): { [number]: { [string]: any } }
	local claimed = {}
	for _, state in pairs(SpawnPointsById) do
		if state.Type == "Harvest" and state.Status == "Claimed" then
			table.insert(claimed, {
				SpawnId = state.Id,
				PrefabId = state.PrefabId,
				ColumnX = state.ColumnX,
				ColumnZ = state.ColumnZ,
				MarkerId = state.MarkerId,
			})
		end
	end
	return claimed
end

function WorldSpawnServiceServer.PruneCollapsedColumns(columns: { [number]: { [string]: any } }): number
	local collapsedColumns = {} :: { [string]: boolean }
	for _, column in ipairs(columns) do
		if type(column) == "table" and type(column.X) == "number" and type(column.Z) == "number" then
			collapsedColumns[columnKey(math.floor(column.X), math.floor(column.Z))] = true
		end
	end

	if next(collapsedColumns) == nil then
		return 0
	end

	local removedCount = 0
	local statesToRemove = {} :: { SpawnPointState }
	for _, state in pairs(SpawnPointsById) do
		if collapsedColumns[columnKey(state.ColumnX, state.ColumnZ)] then
			table.insert(statesToRemove, state)
		end
	end

	for _, state in ipairs(statesToRemove) do
		if SpawnPointsById[state.Id] then
			if state.Type == "Treasure" then
				destroyTreasureModel(state)
			elseif state.Type == "Harvest" then
				destroyHarvestModel(state)
			end

			unregisterSpawnState(state)
			removedCount += 1
		end
	end

	if removedCount > 0 then
		rebuildDebugAnchors()
	end

	return removedCount
end

function WorldSpawnServiceServer.GetSpawnPointCount(): number
	local count = 0
	for _ in pairs(SpawnPointsById) do
		count += 1
	end
	return count
end

function WorldSpawnServiceServer.SetDebugOverrides(overrides: { [string]: any }?)
	local nextGenerationType = GENERATION_TYPE_STANDARD
	local nextEnemyBaseLevel = nil :: number?
	if type(overrides) == "table" then
		nextGenerationType = normalizeGenerationType(overrides.GenerationType)
		nextEnemyBaseLevel = normalizeEnemyBaseLevel(overrides.EnemyBaseLevel)
	end

	RuntimeDebugOverrides.GenerationType = nextGenerationType
	RuntimeDebugOverrides.EnemyBaseLevel = nextEnemyBaseLevel
end

function WorldSpawnServiceServer.GetDebugOverrides(): SpawnDebugOverrides
	return {
		GenerationType = RuntimeDebugOverrides.GenerationType,
		EnemyBaseLevel = RuntimeDebugOverrides.EnemyBaseLevel,
	}
end

Players.PlayerRemoving:Connect(function(player)
	WorldSpawnServiceServer.ClearPlayerChunks(player)
end)

return table.freeze(WorldSpawnServiceServer)
