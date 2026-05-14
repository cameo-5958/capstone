--!strict
-- Creates and handles enemies

-- Create RemoteEvent for Enemy API
local API = Instance.new("RemoteEvent")
API.Parent = script.Parent
API.Name = "EnemyEndpoint"

-- Create RemoteEvent for Enemy API
local Handler = Instance.new("RemoteEvent")
Handler.Parent = script.Parent
Handler.Name = "EnemyHandler"

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Brains = require(ReplicatedStorage.Classes.Enemy.Brains)
local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local Movement = require(ReplicatedStorage.Classes.Entity.EntityMovement)
local CollisionServiceServer = require(ReplicatedStorage.Services.Collision.CollisionServiceServer)
local DefaultAnimations = require(ReplicatedStorage.Database.Enemies.Default.Animations)
local InventoryItemRegistry = require(ReplicatedStorage.Database.InventoryItems.Registry)
local EquipmentServiceServer = require(ReplicatedStorage.Services.Equipment.EquipmentServiceServer)
local LevelScaling = require(ReplicatedStorage.Modules.Progression.LevelScaling)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local ItemDropServiceServer = nil :: any

-- Use Entities class
type Entity = EntityTypes.Entity

-- Load Entity registry folder
local Database = ReplicatedStorage:WaitForChild("Database")
local EnemiesDatabase = Database.Enemies

-- Create Folder for enemies to be stored in
local EnemyFolder = workspace:WaitForChild("EntitiesFolder")
local __Enemies: {
	[string]: Entity, -- UUID -> Entity

	-- Methods
} = {}
local __EnemyRuntime: {
	[string]: {
		Entity: Entity,
		MovementEngine: any,
		Brain: any,
		DeathConnection: any,
		SpawnOptions: { [string]: any }?,
		IsDying: boolean?,
	},
} =
	{}
local __Deaths: {
	[string]: {
		UUID: string,
		Position: Vector3,
		DiedAt: number,
		Entity: Entity,
	},
} = {}

local Enemies = {}
local ENEMY_LEVEL_STEP = 0
local DEFAULT_ENEMY_START_LEVEL = 1
local NextSpawnLevel = DEFAULT_ENEMY_START_LEVEL
local ESCAPE_MEMORY_DURATION = 30
local DEATH_DESPAWN_DELAY = 2.5
local DEATH_BURST_HORIZONTAL_SPEED = 16
local DEATH_BURST_VERTICAL_SPEED = 10
local DEATH_BURST_RANDOM_SPEED = 5
local DEATH_BURST_ANGULAR_SPEED = 8
local DROP_SCATTER_RADIUS = 2.25

type EnemyDropDefinition = {
	ItemKind: string,
	ItemId: string?,
	StackKey: string?,
	Quantity: number?,
	MaxStack: number?,
	Chance: number?,
	Data: { [string]: any }?,
}

local function GetNextSpawnLevel(): number
	local level = LevelScaling.ClampLevel(NextSpawnLevel)
	NextSpawnLevel = LevelScaling.ClampLevel(NextSpawnLevel + ENEMY_LEVEL_STEP)
	return level
end

local function ResolveSpawnLevel(levelOverride: number?): number
	if levelOverride ~= nil then
		return LevelScaling.ClampLevel(levelOverride)
	end

	return GetNextSpawnLevel()
end

local function HideHumanoidOverhead(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayDistance = 0
	humanoid.NameDisplayDistance = 0
	humanoid.DisplayName = ""
end

local function SetServerNetworkOwnership(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:CanSetNetworkOwnership() then
			descendant:SetNetworkOwner(nil)
		end
	end
end

local function RemoveEnemyForClients(uuid: string)
	API:FireAllClients({
		Remove = {
			[uuid] = true,
		},
	})
end

local function DestroyEnemyRuntime(runtime: {
	Entity: Entity,
	MovementEngine: any,
	Brain: any,
	DeathConnection: any,
	SpawnOptions: { [string]: any }?,
	IsDying: boolean?,
}?)
	if not runtime then
		return
	end

	if runtime.DeathConnection then
		runtime.DeathConnection:Disconnect()
		runtime.DeathConnection = nil
	end
	if runtime.Brain then
		runtime.Brain:Destroy()
		runtime.Brain = nil
	end
	if runtime.MovementEngine then
		runtime.MovementEngine:Destroy()
		runtime.MovementEngine = nil
	end
end

local function cloneData(data: { [string]: any }?): { [string]: any }
	local clone = {}
	if not data then
		return clone
	end

	for key, value in pairs(data) do
		clone[key] = value
	end

	return clone
end

local function getItemDropServiceServer()
	if ItemDropServiceServer == nil then
		ItemDropServiceServer = require(ReplicatedStorage.Services.ItemDrop.ItemDropServiceServer)
	end
	return ItemDropServiceServer
end

local function resolveDropGrant(drop: EnemyDropDefinition): (string?, { [string]: any }?, string?, number?)
	local itemKind = drop.ItemKind
	if type(itemKind) ~= "string" or itemKind == "" then
		return nil, nil, nil, nil
	end

	if itemKind == "InventoryItem" then
		local itemId = drop.ItemId
		if type(itemId) ~= "string" or itemId == "" then
			return nil, nil, nil, nil
		end

		local definition = InventoryItemRegistry.Get(itemId)
		if not definition then
			return nil, nil, nil, nil
		end

		return itemKind, {
			Kind = "Item",
			ItemId = definition.Id,
		}, "InventoryItem:" .. definition.Id, definition.MaxStack
	end

	return itemKind, cloneData(drop.Data), drop.StackKey, drop.MaxStack
end

local function spawnEnemyDrops(entity: Entity)
	local enemyDrops = (entity :: any).__Drops
	if type(enemyDrops) ~= "table" or #enemyDrops <= 0 then
		return
	end

	local origin = entity.RootPart and entity.RootPart.Position
	if typeof(origin) ~= "Vector3" then
		return
	end

	local rng = Random.new()
	local droppedCount = 0
	for _, drop in ipairs(enemyDrops) do
		if type(drop) ~= "table" then
			continue
		end

		local quantity = math.max(0, math.floor(drop.Quantity or 1))
		local chance = math.clamp(type(drop.Chance) == "number" and drop.Chance or 1, 0, 1)
		if quantity <= 0 or chance <= 0 or rng:NextNumber() > chance then
			continue
		end

		local itemKind, data, stackKey, maxStack = resolveDropGrant(drop :: EnemyDropDefinition)
		if not itemKind or not stackKey then
			continue
		end

		droppedCount += 1
		local angle = (droppedCount / math.max(1, #enemyDrops)) * math.pi * 2
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * DROP_SCATTER_RADIUS
		getItemDropServiceServer().DropStackGrant(origin + offset, {
			ItemKind = itemKind,
			StackKey = stackKey,
			Quantity = quantity,
			MaxStack = maxStack,
			Data = data,
		})
	end
end

local function WipeEntity(uuid: string, asDeath: boolean?)
	local runtime = __EnemyRuntime[uuid]
	local entity = runtime and runtime.Entity or __Enemies[uuid]
	if not entity then
		return
	end

	DestroyEnemyRuntime(runtime)

	if asDeath ~= false then
		__Deaths[uuid] = {
			UUID = uuid,
			Position = entity.RootPart.Position,
			DiedAt = workspace:GetServerTimeNow(),
			Entity = entity,
		}
	end
	__EnemyRuntime[uuid] = nil
	__Enemies[uuid] = nil

	-- Ensure server-side enemy model is fully removed from workspace.
	local character = entity.Character
	if character and character.Parent then
		character:Destroy()
	end

	RemoveEnemyForClients(uuid)
end

local function BurstEnemyParts(character: Model, origin: Vector3)
	local randomizer = Random.new()

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Humanoid") then
			local humanoid = descendant :: Humanoid
			humanoid.BreakJointsOnDeath = false
			humanoid.PlatformStand = true
		elseif
			descendant:IsA("Motor6D")
			or descendant:IsA("Weld")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("Snap")
		then
			descendant:Destroy()
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if not descendant:IsA("BasePart") then
			continue
		end

		local part = descendant :: BasePart
		local isRoot = part.Name == "HumanoidRootPart"
		part.Anchored = false
		part.Massless = false
		part.CanCollide = not isRoot
		part.CanTouch = false
		part.CanQuery = not isRoot

		local direction = part.Position - origin
		if direction.Magnitude < 0.05 then
			direction = Vector3.new(
				randomizer:NextNumber(-1, 1),
				randomizer:NextNumber(0.15, 0.75),
				randomizer:NextNumber(-1, 1)
			)
		end

		local unitDirection = direction.Unit
		local randomVelocity = Vector3.new(
			randomizer:NextNumber(-DEATH_BURST_RANDOM_SPEED, DEATH_BURST_RANDOM_SPEED),
			randomizer:NextNumber(0, DEATH_BURST_RANDOM_SPEED),
			randomizer:NextNumber(-DEATH_BURST_RANDOM_SPEED, DEATH_BURST_RANDOM_SPEED)
		)
		part.AssemblyLinearVelocity = (unitDirection * DEATH_BURST_HORIZONTAL_SPEED)
			+ Vector3.new(0, DEATH_BURST_VERTICAL_SPEED, 0)
			+ randomVelocity
		part.AssemblyAngularVelocity = Vector3.new(
			randomizer:NextNumber(-DEATH_BURST_ANGULAR_SPEED, DEATH_BURST_ANGULAR_SPEED),
			randomizer:NextNumber(-DEATH_BURST_ANGULAR_SPEED, DEATH_BURST_ANGULAR_SPEED),
			randomizer:NextNumber(-DEATH_BURST_ANGULAR_SPEED, DEATH_BURST_ANGULAR_SPEED)
		)
	end

	Debris:AddItem(character, DEATH_DESPAWN_DELAY + 0.5)
end

local function StartEnemyDeath(uuid: string)
	local runtime = __EnemyRuntime[uuid]
	local entity = runtime and runtime.Entity or __Enemies[uuid]
	if not runtime or not entity or runtime.IsDying then
		return
	end

	runtime.IsDying = true
	DestroyEnemyRuntime(runtime)

	__Deaths[uuid] = {
		UUID = uuid,
		Position = entity.RootPart.Position,
		DiedAt = workspace:GetServerTimeNow(),
		Entity = entity,
	}

	local character = entity.Character
	if character and character.Parent then
		BurstEnemyParts(character, entity.RootPart.Position)
	end

	task.delay(DEATH_DESPAWN_DELAY, function()
		if __Enemies[uuid] == entity then
			WipeEntity(uuid, false)
		end
	end)
end

local function resolveSpawnCFrame(spawnTarget: any): CFrame
	if typeof(spawnTarget) == "CFrame" then
		return spawnTarget
	end
	if typeof(spawnTarget) == "Vector3" then
		return CFrame.new(spawnTarget)
	end
	if typeof(spawnTarget) == "Instance" and (spawnTarget :: Instance):IsA("BasePart") then
		return (spawnTarget :: BasePart).CFrame
	end

	error("Enemy spawn target must be BasePart, CFrame, or Vector3")
end

local function SerializeEntityForClient(entity: Entity): { [string]: any }
	return {
		UUID = entity.UUID,
		Name = entity.Name,
		Family = entity.Family,
		Level = entity.Level,
		__ScaledLevel = entity.__ScaledLevel,
		Character = entity.Character,
		RootPart = entity.RootPart,
		__Stats = table.clone(entity.__Stats),
		__Animations = table.clone(entity.__Animations),
		__Buffs = {},
		__AttackModifierAppliers = {},
		__Components = {
			EquippedIndex = nil,
			ToolbarWeapons = { nil, nil, nil, nil },
			ComboState = {
				WeaponClass = nil,
				ComboId = nil,
				AttackIndex = entity.__Components.ComboState.AttackIndex,
				LastAttackAt = entity.__Components.ComboState.LastAttackAt,
			},
		},
		__Alive = entity.__Alive,
		__InvincibleUntil = entity.__InvincibleUntil,
	}
end

local function SerializeEnemiesForClient(enemies: { [string]: Entity }): { [string]: any }
	local serialized = {}
	for uuid, entity in pairs(enemies) do
		serialized[uuid] = SerializeEntityForClient(entity)
	end

	return serialized
end

-- When players are added, send all the
-- Entities as deserialized data
Players.PlayerAdded:Connect(function(player)
	API:FireClient(player, {
		["Create"] = SerializeEnemiesForClient(__Enemies),
	})
end)

API.OnServerEvent:Connect(function(_: Player, action: string, payload: { [string]: any }?)
	if action == "RequestSpawnEnemy" then
		local enemyPath = payload and payload.EnemyPath or "Skeletal.Base"
		local levelOverride = payload and payload.Level
		local spawnPart = workspace:FindFirstChild("SpawnPoint")
		if spawnPart and spawnPart:IsA("Part") then
			Enemies.Spawn(enemyPath, spawnPart, if type(levelOverride) == "number" then levelOverride else nil)
		end
	end
end)

-- Entity creation
local default = {
	Strength = 0,
	CritRate = 0,
	CritDamage = 0,
	MagicalAttack = 0,
}

local function resolveEnemyFolder(enemyPath: string): Instance
	local pathParts = enemyPath:split(".")
	local current: Instance = EnemiesDatabase
	for _, part in ipairs(pathParts) do
		current = current:WaitForChild(part)
	end
	return current
end

local function buildEnemyModel(enemyFolder: Instance, enemyPath: string): Model
	local modelInstance = enemyFolder:FindFirstChild("Model")
	if modelInstance and modelInstance:IsA("Model") then
		return modelInstance:Clone()
	end

	local modelBuilderModule = enemyFolder:FindFirstChild("ModelBuilder")
	if modelBuilderModule and modelBuilderModule:IsA("ModuleScript") then
		local ok, exported = pcall(require, modelBuilderModule)
		if not ok then
			error(string.format("Failed to require model builder for '%s': %s", enemyPath, tostring(exported)))
		end

		local builderFn: (() -> Model)? = nil
		if type(exported) == "function" then
			builderFn = exported
		elseif type(exported) == "table" and type((exported :: any).Build) == "function" then
			builderFn = function()
				return (exported :: any).Build()
			end
		end
		if not builderFn then
			error(string.format("ModelBuilder for '%s' must export a function or table with Build()", enemyPath))
		end

		local builtModel = builderFn()
		if not builtModel or not builtModel:IsA("Model") then
			error(string.format("ModelBuilder for '%s' did not return a Model", enemyPath))
		end
		return builtModel
	end

	error(string.format("Enemy '%s' is missing a Model or ModelBuilder", enemyPath))
end

local function findBestRootPart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	local namedRoot = model:FindFirstChild("HumanoidRootPart")
	if namedRoot and namedRoot:IsA("BasePart") then
		return namedRoot
	end

	local firstBasePart = model:FindFirstChildWhichIsA("BasePart", true)
	if firstBasePart then
		return firstBasePart
	end

	return nil
end

local function ensureEnemyRigRequirements(model: Model)
	local rootPart = findBestRootPart(model)
	if not rootPart then
		error(string.format("Enemy model '%s' has no BasePart to serve as root", model.Name))
	end

	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and not humanoidRootPart:IsA("BasePart") then
		humanoidRootPart:Destroy()
		humanoidRootPart = nil
	end

	if not humanoidRootPart then
		local createdRoot = Instance.new("Part")
		createdRoot.Name = "HumanoidRootPart"
		createdRoot.Size = Vector3.new(2, 2, 1)
		createdRoot.Transparency = 1
		createdRoot.CanCollide = false
		createdRoot.CanTouch = false
		createdRoot.CanQuery = false
		createdRoot.Anchored = false
		createdRoot.Massless = true
		createdRoot.CFrame = rootPart.CFrame
		createdRoot.Parent = model

		local rootWeld = Instance.new("WeldConstraint")
		rootWeld.Name = "RootWeld"
		rootWeld.Part0 = createdRoot
		rootWeld.Part1 = rootPart
		rootWeld.Parent = createdRoot

		humanoidRootPart = createdRoot
	end

	local rootAttachment = humanoidRootPart:FindFirstChild("RootAttachment")
	if not rootAttachment then
		rootAttachment = Instance.new("Attachment")
		rootAttachment.Name = "RootAttachment"
		rootAttachment.Parent = humanoidRootPart
	end

	local humanoid = model:FindFirstChild("Humanoid")
	if humanoid and not humanoid:IsA("Humanoid") then
		humanoid:Destroy()
		humanoid = nil
	end
	if not humanoid then
		humanoid = Instance.new("Humanoid")
		humanoid.Name = "Humanoid"
		humanoid.Parent = model
	end
	humanoid.BreakJointsOnDeath = false

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local isRoot = part == humanoidRootPart
			part.Anchored = false
			-- Keep one stable grounding collider; non-root parts should not fight each other.
			part.CanCollide = isRoot
			part.CanTouch = isRoot
		end
	end

	model.PrimaryPart = humanoidRootPart
end

local function tunePassivePreyCollider(model: Model)
	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return
	end

	local minX = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxZ = -math.huge
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			if part ~= humanoidRootPart then
				local halfX = part.Size.X * 0.5
				local halfZ = part.Size.Z * 0.5
				minX = math.min(minX, part.Position.X - halfX)
				maxX = math.max(maxX, part.Position.X + halfX)
				minZ = math.min(minZ, part.Position.Z - halfZ)
				maxZ = math.max(maxZ, part.Position.Z + halfZ)
			end
		end
	end

	if minX == math.huge or minZ == math.huge then
		return
	end

	local width = math.max(2, maxX - minX)
	local depth = math.max(2, maxZ - minZ)
	local targetX = math.clamp(width * 0.62, 2.4, 7)
	local targetZ = math.clamp(depth * 0.62, 2.4, 7)
	local rootY = math.max(2.2, humanoidRootPart.Size.Y)

	local existingHull = model:FindFirstChild("CollisionHull")
	if existingHull then
		existingHull:Destroy()
	end

	humanoidRootPart.Size = Vector3.new(targetX, rootY, targetZ)
	humanoidRootPart.CanCollide = true
	humanoidRootPart.CanTouch = true
	humanoidRootPart.CanQuery = true
end

function Enemies.Spawn(
	e: string,
	spawnTarget: Part | BasePart | CFrame | Vector3,
	levelOverride: number?,
	spawnOptions: { [string]: any }?
): Entity?
	local spawnLevel = ResolveSpawnLevel(levelOverride)
	local spawnCFrame = resolveSpawnCFrame(spawnTarget)

	-- Grab enemy's data from the database
	-- Split Enemy into multiple parts
	local Enemy = resolveEnemyFolder(e)

	-- Require the data to create the entity
	local data = require(Enemy.Data) :: { ["Name"]: string, string: any }
	local model = buildEnemyModel(Enemy, e)
	ensureEnemyRigRequirements(model)
	model:SetAttribute("EnemyLevel", spawnLevel)
	local mergedAnimations = table.clone(DefaultAnimations)
	for key, value in pairs(data.__Animations or {}) do
		mergedAnimations[key] = value
	end

	HideHumanoidOverhead(model)
	CollisionServiceServer.AssignModel(model, "Enemy")

	-- Create the entity here
	local entity = Entity.new(model, data.Name, spawnLevel)
	model:PivotTo(spawnCFrame)
	model.Name = entity.UUID
	local spawnContext: { [string]: any }? = nil
	if spawnOptions and type(spawnOptions.SpawnContext) == "table" then
		local context = spawnOptions.SpawnContext
		spawnContext = context
		if type(context.SpawnPointId) == "string" then
			model:SetAttribute("WorldSpawnPointId", context.SpawnPointId)
		end
		if type(context.PrefabId) == "string" then
			model:SetAttribute("WorldSpawnPrefabId", context.PrefabId)
		end
		if type(context.MarkerId) == "string" then
			model:SetAttribute("WorldSpawnMarkerId", context.MarkerId)
		end
	end
	entity.__Animations = mergedAnimations
	-- Set default enemy stats
	for key, value in pairs(default) do
		entity:SetStat(key, value)
	end

	-- Set enemy specific stats
	for key, value in pairs(data) do
		if key == "__Stats" then
			for statName, statValue in pairs(value) do
				entity:SetStat(statName, statValue)
			end
			continue
		end
		if key == "__Animations" then
			continue
		end
		if key == "__Components" then
			continue
		end

		-- Check type of entity[key]
		if typeof(entity[key]) == typeof(table) then
			-- Add them one by one
			for k, v in pairs(value) do
				entity[key][k] = v
			end
		else
			entity[key] = value
		end
	end

	LevelScaling.ApplyScaling(entity)

	-- World spawns can grant additional HP based on distance from center.
	if spawnContext and type(spawnContext.HealthBonus) == "number" then
		local hpBonus = math.clamp(math.floor(spawnContext.HealthBonus), 0, 5)
		if hpBonus > 0 then
			local maxHealth = entity:GetStat("MaxHealth")
			if type(maxHealth) == "number" then
				local boostedMax = maxHealth + hpBonus
				entity:SetStat("MaxHealth", boostedMax)
				-- Spawned enemies should always start at full health after scaling.
				entity:SetStat("Health", boostedMax)
			end
		end
	end

	-- Parent only after stats/scaling are finalized so clients see the final values immediately.
	model.Parent = EnemyFolder
	SetServerNetworkOwnership(model)

	local brainProfile = data.__BrainProfile
	if brainProfile == "PassivePrey" then
		if not (data.__Stats and type(data.__Stats.Speed) == "number") then
			entity:SetStat("Speed", 4)
		end
		tunePassivePreyCollider(model)
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi, 0))
	end

	local toolbarWeapons = data.__Components and data.__Components.ToolbarWeapons
	if toolbarWeapons then
		for slot, weaponPath in ipairs(toolbarWeapons) do
			if weaponPath ~= nil then
				EquipmentServiceServer.AssignToolbarWeapon(entity, weaponPath, slot)
			end
		end
	end

	local equippedIndex = data.__Components and data.__Components.EquippedIndex
	if type(equippedIndex) == "number" then
		entity:SetEquippedIndex(equippedIndex)
	end

	local spawnPosition = spawnCFrame.Position
	if spawnContext and type(spawnContext.SpawnPointId) == "string" and spawnContext.SpawnPointId ~= "" then
		print(
			string.format(
				"[EnemyService] Spawn enemy=%s uuid=%s level=%d spawnPoint=%s position=(%.2f, %.2f, %.2f)",
				e,
				entity.UUID,
				spawnLevel,
				spawnContext.SpawnPointId,
				spawnPosition.X,
				spawnPosition.Y,
				spawnPosition.Z
			)
		)
	else
		print(
			string.format(
				"[EnemyService] Spawn enemy=%s uuid=%s level=%d position=(%.2f, %.2f, %.2f)",
				e,
				entity.UUID,
				spawnLevel,
				spawnPosition.X,
				spawnPosition.Y,
				spawnPosition.Z
			)
		)
	end

	-- Add to the database
	__Enemies[entity.UUID] = entity

	-- Give it its engines
	local movementEngine = Movement.new(entity)
	local brain = if brainProfile == "PassivePrey"
		then Brains.PassivePrey(movementEngine, 32)
		else Brains.Aggressive(movementEngine, 32)
	local deathConnection = entity:GetStatChangedSignal("Health"):Connect(function(newValue: number)
		if newValue <= 0 then
			spawnEnemyDrops(entity)
			if spawnOptions and type(spawnOptions.OnDeath) == "function" then
				local ok, callbackError = pcall(function()
					spawnOptions.OnDeath(entity.UUID, entity)
				end)
				if not ok then
					warn(
						string.format(
							"[EnemyServiceServer] OnDeath callback failed for %s: %s",
							entity.UUID,
							tostring(callbackError)
						)
					)
				end
			end
			StartEnemyDeath(entity.UUID)
		end
	end)
	__EnemyRuntime[entity.UUID] = {
		Entity = entity,
		MovementEngine = movementEngine,
		Brain = brain,
		DeathConnection = deathConnection,
		SpawnOptions = spawnOptions,
	}

	-- Start the brain loop
	brain:Go()

	-- Send the entity to all clients
	API:FireAllClients({
		["Create"] = {
			[entity.UUID] = SerializeEntityForClient(entity),
		},
	})

	return entity
end

function Enemies.RegisterDamagedBy(target: Entity, source: Entity)
	if not target or not source then
		return false
	end

	local runtime = __EnemyRuntime[target.UUID]
	if not runtime or not runtime.Brain then
		return false
	end

	local sourceCharacter = source.Character
	if not sourceCharacter or not sourceCharacter:IsA("Model") then
		return false
	end

	local sourcePlayerEntity = PlayerServiceServer.GetEntityFromCharacter(sourceCharacter)
	if not sourcePlayerEntity then
		return false
	end

	runtime.Brain:QueueEscapeFromPlayer(sourceCharacter, ESCAPE_MEMORY_DURATION)
	return true
end

function Enemies.Despawn(uuid: string): boolean
	if not __Enemies[uuid] then
		return false
	end

	WipeEntity(uuid, false)
	return true
end

function Enemies.DespawnAll(): number
	local uuids = {}
	for uuid in pairs(__Enemies) do
		table.insert(uuids, uuid)
	end

	for _, uuid in ipairs(uuids) do
		WipeEntity(uuid, false)
	end

	return #uuids
end

function Enemies.GetClosest(position: Vector3, sight: number?): Entity?
	local closest: Entity? = nil
	local closestDistance = sight or math.huge

	for _, entity in pairs(__Enemies) do
		if entity:IsAlive() then
			local distance = (entity.RootPart.Position - position).Magnitude
			if distance < closestDistance then
				closest = entity
				closestDistance = distance
			end
		end
	end

	return closest
end

function Enemies.GetByUUID(uuid: string): Entity?
	return __Enemies[uuid]
end

function Enemies.GetInRadius(position: Vector3, radius: number): { Entity }
	local results = {}
	local limit = math.max(0, radius)
	for _, entity in pairs(__Enemies) do
		if entity:IsAlive() then
			local distance = (entity.RootPart.Position - position).Magnitude
			if distance <= limit then
				table.insert(results, entity)
			end
		end
	end
	return results
end

function Enemies.RegisterHeavyHit(target: Entity, source: Entity?)
	local runtime = target and __EnemyRuntime[target.UUID]
	if not runtime or not runtime.Brain then
		return false
	end

	runtime.Brain:QueueStumble(source and source.RootPart and source.RootPart.Position or nil)
	return true
end

function Enemies.GetDeaths()
	return __Deaths
end

return Enemies
