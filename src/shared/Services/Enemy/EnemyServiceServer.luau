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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Brains = require(ReplicatedStorage.Classes.Enemy.Brains)
local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local Movement = require(ReplicatedStorage.Classes.Entity.EntityMovement)
local CollisionServiceServer = require(ReplicatedStorage.Services.Collision.CollisionServiceServer)
local DefaultAnimations = require(ReplicatedStorage.Database.Enemies.Default.Animations)
local EquipmentServiceServer = require(ReplicatedStorage.Services.Equipment.EquipmentServiceServer)
local LevelScaling = require(ReplicatedStorage.Modules.Progression.LevelScaling)

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
	},
} = {}
local __Deaths: {
	[string]: {
		UUID: string,
		Position: Vector3,
		DiedAt: number,
		Entity: Entity,
	},
} = {}

local Enemies = {}
local ENEMY_LEVEL_STEP = 5
local DEFAULT_ENEMY_START_LEVEL = 5
local NextSpawnLevel = DEFAULT_ENEMY_START_LEVEL

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

local function WipeEntity(uuid: string, asDeath: boolean?)
	local runtime = __EnemyRuntime[uuid]
	local entity = runtime and runtime.Entity or __Enemies[uuid]
	if not entity then
		return
	end

	if runtime then
		if runtime.DeathConnection then
			runtime.DeathConnection:Disconnect()
			runtime.DeathConnection = nil
		end
		if runtime.Brain then
			runtime.Brain:Destroy()
		end
		if runtime.MovementEngine then
			runtime.MovementEngine:Destroy()
		end
	end

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
	RemoveEnemyForClients(uuid)
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
		local enemyPath = payload and payload.EnemyPath or "Golem.Basalt"
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

function Enemies.Spawn(
	e: string,
	spawnTarget: Part | BasePart | CFrame | Vector3,
	levelOverride: number?,
	spawnOptions: { [string]: any }?
): Entity?
	local spawnLevel = ResolveSpawnLevel(levelOverride)

	-- Grab enemy's data from the database
	-- Split Enemy into multiple parts
	local Enemy = resolveEnemyFolder(e)

	-- Require the data to create the entity
	local data = require(Enemy.Data) :: { ["Name"]: string, string: any }
	local model = buildEnemyModel(Enemy, e)
	model:SetAttribute("EnemyLevel", spawnLevel)
	local mergedAnimations = table.clone(DefaultAnimations)
	for key, value in pairs(data.__Animations or {}) do
		mergedAnimations[key] = value
	end

	HideHumanoidOverhead(model)
	CollisionServiceServer.AssignModel(model, "Enemy")

	-- Create the entity here
	local entity = Entity.new(model, data.Name)
	model:PivotTo(resolveSpawnCFrame(spawnTarget))
	model.Name = entity.UUID
	if spawnOptions and type(spawnOptions.SpawnContext) == "table" then
		local context = spawnOptions.SpawnContext
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
	model.Parent = EnemyFolder
	SetServerNetworkOwnership(model)

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

	entity.Level = spawnLevel
	entity.__ScaledLevel = spawnLevel
	LevelScaling.ApplyScaling(entity)

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

	print(entity)

	-- Add to the database
	__Enemies[entity.UUID] = entity

	-- Give it its engines
	local movementEngine = Movement.new(entity)
	local brain = Brains.Aggressive(movementEngine, 32)
	local deathConnection = entity:GetStatChangedSignal("Health"):Connect(function(newValue: number)
		if newValue <= 0 then
			if spawnOptions and type(spawnOptions.OnDeath) == "function" then
				local ok, callbackError = pcall(function()
					spawnOptions.OnDeath(entity.UUID, entity)
				end)
				if not ok then
					warn(string.format("[EnemyServiceServer] OnDeath callback failed for %s: %s", entity.UUID, tostring(callbackError)))
				end
			end
			WipeEntity(entity.UUID, true)
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

function Enemies.Despawn(uuid: string): boolean
	if not __Enemies[uuid] then
		return false
	end

	WipeEntity(uuid, false)
	return true
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
