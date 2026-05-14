--!strict
-- A simple Service that keeps
-- track of players and runs personalized
-- methods

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local CollisionServiceServer = require(ReplicatedStorage.Services.Collision.CollisionServiceServer)
local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
local WeaponServiceServer = require(ReplicatedStorage.Services.Weapon.WeaponServiceServer)
local InventoryItemRegistry = require(ReplicatedStorage.Database.InventoryItems.Registry)
local PlayerConfig = require(ReplicatedStorage.Database.Players.Default.Data)
local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")

local PlayerServiceServer = {}

type Entity = EntityTypes.Entity
type Connection = {
	Disconnect: (self: Connection) -> (),
}

-- Store player Characters here
local PlayerCharacters: { [string]: Entity } = {}
local PlayerStatConnections: { [string]: { Connection } } = {}
local PlayerRuntimeState: {
	[string]: {
		AttackUntil: number,
		IsHeavyAttackActive: boolean,
		HeavyAttackUntil: number,
		DashUntil: number,
		RunningEligibleUntil: number,
		IsRightClickHeld: boolean,
		IsRunning: boolean,
		RunLockedUntilRelease: boolean,
		StaminaRampStartAt: number,
		StaminaRampEndAt: number,
		RunningSpeedHandle: EntityTypes.ModifierHandle?,
	},
} = {}
local STAT_NAMES = {
	"Health",
	"MaxHealth",
	"Mana",
	"MaxMana",
	"Stamina",
	"MaxStamina",
	"Defense",
	"Strength",
	"CritRate",
	"CritDamage",
	"Intelligence",
	"ManaRegen",
	"StaminaRegen",
	"ManaConsumptionRate",
	"StaminaConsumptionRate",
	"ArrowTravelDistance",
	"PhysicalAttack",
	"MagicalAttack",
	"PhysicalDamage",
	"MagicDamage",
	"DamageTakenMultiplier",
	"Speed",
}

local endpoint = script.Parent:FindFirstChild("PlayerEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "PlayerEndpoint"
	endpoint.Parent = script.Parent
end
local API = endpoint :: RemoteEvent
local DASH_IFRAME_DURATION = 0.32
local DASH_IFRAME_COOLDOWN = 0.3
local DASH_STAMINA_COST = 20
local LIGHT_ATTACK_STAMINA_COST = 15
local HEAVY_ATTACK_STAMINA_COST = 25
local BASE_MANA_REGEN = 5
local BASE_STAMINA_REGEN = 30
local ATTACKING_STAMINA_REGEN = 4
local RUNNING_STAMINA_DRAIN = 10
local STAMINA_RAMP_DURATION = 0.4
local RUN_SPEED_MULTIPLIER = 1.8
local RUNNING_SPEED_MODIFIER_ID = "system:running:speed"
local PlayerNextDashIframeAt: { [string]: number } = {}
local DebugWeaponPaths: { string }? = nil
local DebugSpawnableItems: { {
	ItemId: string,
	Name: string,
	Desc: string,
	Icon: string,
	MaxStack: number,
	SpawnWith: number,
	CanEquip: boolean,
	CanUse: boolean,
	EquipSlotType: string?,
	ModelAssetName: string?,
	InventoryData: { [string]: any }?,
	UseEffects: { [string]: any }?,
} }? = nil

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

local function collectWeaponPaths(root: Instance, currentPath: string?, paths: { string }): ()
	if root:FindFirstChild("Data") then
		if currentPath and currentPath ~= "" then
			table.insert(paths, currentPath)
		end
		return
	end

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Folder") then
			local nextPath = if currentPath and currentPath ~= "" then currentPath .. "." .. child.Name else child.Name
			collectWeaponPaths(child, nextPath, paths)
		end
	end
end

local function getDebugWeaponPaths(): { string }
	if DebugWeaponPaths then
		return DebugWeaponPaths
	end

	local paths = {}
	collectWeaponPaths(WeaponsDatabase, nil, paths)
	table.sort(paths)
	DebugWeaponPaths = paths
	return paths
end

local function getDebugSpawnableItems(): { {
	ItemId: string,
	Name: string,
	Desc: string,
	Icon: string,
	MaxStack: number,
	SpawnWith: number,
	CanEquip: boolean,
	CanUse: boolean,
	EquipSlotType: string?,
	ModelAssetName: string?,
	InventoryData: { [string]: any }?,
	UseEffects: { [string]: any }?,
} }
	if DebugSpawnableItems then
		return DebugSpawnableItems
	end

	local items = {}
	for _, item in pairs(InventoryItemRegistry.GetAll()) do
		table.insert(items, {
			ItemId = item.Id,
			Name = item.Name,
			Desc = item.Desc,
			Icon = item.Icon,
			MaxStack = item.MaxStack,
			SpawnWith = item.SpawnWith,
			CanEquip = item.CanEquip,
			CanUse = item.CanUse,
			EquipSlotType = item.EquipSlotType,
			ModelAssetName = item.ModelAssetName,
			InventoryData = cloneData(item.InventoryData),
			UseEffects = cloneData(item.UseEffects),
		})
	end

	table.sort(items, function(left, right)
		return left.ItemId < right.ItemId
	end)

	DebugSpawnableItems = items
	return items
end

local function debugGrantAllWeapons(player: Player)
	for _, weaponPath in ipairs(getDebugWeaponPaths()) do
		InventoryServiceServer.AddWeaponFromPath(player, weaponPath)
	end
end

local function debugGrantAllNonConsumableItems(player: Player)
	for _, item in ipairs(getDebugSpawnableItems()) do
		InventoryServiceServer.AddStackableItem(
			player,
			"InventoryItem",
			"InventoryItem:" .. item.ItemId,
			{
				Kind = "Item",
				ItemId = item.ItemId,
				Name = item.Name,
				Desc = item.Desc,
				Icon = item.Icon,
				MaxStack = item.MaxStack,
				SpawnWith = item.SpawnWith,
				CanEquip = item.CanEquip,
				CanUse = item.CanUse,
				EquipSlotType = item.EquipSlotType,
				ModelAssetName = item.ModelAssetName,
				InventoryData = item.InventoryData or {},
				UseEffects = item.UseEffects,
			},
			1,
			item.MaxStack
		)
	end
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

local function GetRuntimeState(playerName: string)
	local state = PlayerRuntimeState[playerName]
	if state then
		return state
	end

	state = {
		AttackUntil = 0,
		IsHeavyAttackActive = false,
		HeavyAttackUntil = 0,
		DashUntil = 0,
		RunningEligibleUntil = 0,
		IsRightClickHeld = false,
		IsRunning = false,
		RunLockedUntilRelease = false,
		StaminaRampStartAt = 0,
		StaminaRampEndAt = 0,
		RunningSpeedHandle = nil,
	}
	PlayerRuntimeState[playerName] = state
	return state
end

local function StopRunning(entity: Entity, state): ()
	if not state.IsRunning then
		return
	end

	state.IsRunning = false
	if state.RunningSpeedHandle then
		entity:RemoveModifierHandle(state.RunningSpeedHandle)
		state.RunningSpeedHandle = nil
	end
end

local function BeginStaminaRamp(state, now: number): ()
	state.StaminaRampStartAt = now
	state.StaminaRampEndAt = now + STAMINA_RAMP_DURATION
end

local function TryConsumeStat(entity: Entity, statName: string, amount: number): boolean
	if amount <= 0 then
		return true
	end

	local current = entity:GetStat(statName)
	if current < amount then
		return false
	end

	entity:ModifyStat(statName, -amount)
	return true
end

local function TryConsumeStamina(entity: Entity, amount: number): boolean
	local scaledAmount = amount * entity:GetStat("StaminaConsumptionRate")
	return TryConsumeStat(entity, "Stamina", scaledAmount)
end

local function UpdateDerivedResourceStats(entity: Entity)
	local expectedMaxMana = 100 + entity:GetStat("Intelligence")
	if entity:GetStat("MaxMana") ~= expectedMaxMana then
		entity:SetStat("MaxMana", expectedMaxMana)
	end
end

local function GetStaminaRegenPerSecond(entity: Entity, state, now: number): number
	local regenScale = entity:GetStat("StaminaRegen")
	local baseRegen = BASE_STAMINA_REGEN * regenScale

	if state.IsRunning or now < state.DashUntil or now < state.HeavyAttackUntil then
		return 0
	end

	if state.StaminaRampEndAt > now then
		local duration = math.max(state.StaminaRampEndAt - state.StaminaRampStartAt, 0.001)
		local alpha = math.clamp((now - state.StaminaRampStartAt) / duration, 0, 1)
		return baseRegen * alpha
	end

	if now < state.AttackUntil then
		return ATTACKING_STAMINA_REGEN * regenScale
	end

	return baseRegen
end

local function UpdateRunningState(entity: Entity, state, now: number)
	local humanoid = entity.Character and entity.Character:FindFirstChildOfClass("Humanoid")
	local currentStamina = entity:GetStat("Stamina")
	local minimumRunStamina = RUNNING_STAMINA_DRAIN * entity:GetStat("StaminaConsumptionRate") * 0.15
	local canRun = humanoid ~= nil
		and humanoid.MoveDirection.Magnitude > 0.05
		and state.IsRightClickHeld
		and not state.RunLockedUntilRelease
		and currentStamina > minimumRunStamina
		and now >= state.DashUntil
		and state.RunningEligibleUntil > 0
		and now <= state.RunningEligibleUntil
		and state.AttackUntil <= now
		and state.HeavyAttackUntil <= now

	if canRun then
		if not state.IsRunning then
			state.IsRunning = true
			state.RunningSpeedHandle = entity:AddModifier("Speed", Entity.Modifier.new(
				RUNNING_SPEED_MODIFIER_ID,
				"Multiplicative",
				RUN_SPEED_MULTIPLIER,
				"system:running"
			))
		end
	else
		local wasRunning = state.IsRunning
		StopRunning(entity, state)
		if wasRunning then
			BeginStaminaRamp(state, now)
		end
	end
end

local function GetAttackStaminaCost(entity: Entity, isHeavy: boolean, noStamina: boolean): number
	if noStamina then
		return 0
	end

	local baseCost = if isHeavy then HEAVY_ATTACK_STAMINA_COST else LIGHT_ATTACK_STAMINA_COST
	return baseCost * entity:GetStat("StaminaConsumptionRate")
end

local function DisconnectStatConnections(playerName: string)
	local connections = PlayerStatConnections[playerName]
	if not connections then
		return
	end

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	PlayerStatConnections[playerName] = nil
end

local function SerializeStats(entity: Entity): { [string]: number }
	local stats: { [string]: number } = {}
	for _, statName in ipairs(STAT_NAMES) do
		stats[statName] = entity:GetStat(statName)
	end

	return stats
end

local function SyncStatsToClient(player: Player, entity: Entity)
	API:FireClient(player, "SyncStats", {
		Stats = SerializeStats(entity),
	})
end

local function BindStatReplication(player: Player, entity: Entity)
	DisconnectStatConnections(player.Name)

	local connections = {}
	for _, statName in ipairs(STAT_NAMES) do
		table.insert(connections, entity:GetStatChangedSignal(statName):Connect(function(newValue: number)
			API:FireClient(player, "SyncStat", {
				Stat = statName,
				Value = newValue,
			})
		end))
	end

	PlayerStatConnections[player.Name] = connections
end

local function ApplyPlayerConfigToEntity(entity: Entity)
	for key, value in pairs(PlayerConfig) do
		if key == "__Stats" then
			for statName, statValue in pairs(value) do
				entity:SetStat(statName, statValue)
			end
		elseif typeof(entity[key]) == typeof(table) then
			for nestedKey, nestedValue in pairs(value) do
				entity[key][nestedKey] = nestedValue
			end
		else
			entity[key] = value
		end
	end
end

local function BindCharacter(player: Player, character: Model): Entity
	local animateScript = character:FindFirstChild("Animate")
	if animateScript then
		animateScript:Destroy()
	end

	HideHumanoidOverhead(character)

	CollisionServiceServer.AssignModel(character, "Player")

	local entity = PlayerCharacters[player.Name]

	if entity then
		entity.Character = character
		entity.RootPart = character.PrimaryPart or character:WaitForChild("HumanoidRootPart") :: BasePart
		entity:SyncCharacterStats()
	else
		entity = Entity.new(character, player.Name)
		PlayerCharacters[player.Name] = entity
	end

	ApplyPlayerConfigToEntity(entity)

	local runtimeState = GetRuntimeState(player.Name)
	StopRunning(entity, runtimeState)
	runtimeState.AttackUntil = 0
	runtimeState.IsHeavyAttackActive = false
	runtimeState.HeavyAttackUntil = 0
	runtimeState.DashUntil = 0
	runtimeState.RunningEligibleUntil = 0
	runtimeState.IsRightClickHeld = false
	runtimeState.RunLockedUntilRelease = false
	runtimeState.StaminaRampStartAt = 0
	runtimeState.StaminaRampEndAt = 0
	UpdateDerivedResourceStats(entity)

	BindStatReplication(player, entity)
	SyncStatsToClient(player, entity)

	WeaponServiceServer.RegisterEntity(player, entity)
	WeaponServiceServer.SyncEquippedWeapon(player)

	return entity
end

-- Player added method
local function PlayerAdded(player: Player)
	-- Wait for character to load and store it
	local character = player.Character or player.CharacterAdded:Wait()
	BindCharacter(player, character)
	player.CharacterAdded:Connect(function(nextCharacter)
		BindCharacter(player, nextCharacter)
	end)

	-- Do any additional setup here
end

-- Player removing method
local function PlayerRemoving(player: Player)
	-- Remove player from the table
	local runtimeState = PlayerRuntimeState[player.Name]
	local entity = PlayerCharacters[player.Name]
	if runtimeState and entity then
		StopRunning(entity, runtimeState)
	end
	PlayerCharacters[player.Name] = nil
	PlayerRuntimeState[player.Name] = nil
	DisconnectStatConnections(player.Name)
	PlayerNextDashIframeAt[player.Name] = nil
	WeaponServiceServer.UnregisterEntity(player)

	-- Do any additional cleanup here
end

-- Connect player added and removing events
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

for _, player in pairs(Players:GetPlayers()) do
	PlayerAdded(player)
end

RunService.Heartbeat:Connect(function(dt: number)
	local now = workspace:GetServerTimeNow()
	for playerName, entity in pairs(PlayerCharacters) do
		local state = GetRuntimeState(playerName)
		UpdateDerivedResourceStats(entity)
		UpdateRunningState(entity, state, now)

		if state.IsRunning then
			local drained = RUNNING_STAMINA_DRAIN * entity:GetStat("StaminaConsumptionRate") * dt
			if drained > 0 then
				local currentStamina = entity:GetStat("Stamina")
				if currentStamina <= drained then
					entity:SetStat("Stamina", 0)
					StopRunning(entity, state)
					state.RunLockedUntilRelease = true
					BeginStaminaRamp(state, now)
				else
					entity:ModifyStat("Stamina", -drained)
				end
			end
		end

		local manaRegenPerSecond = BASE_MANA_REGEN * entity:GetStat("ManaRegen")
		if manaRegenPerSecond > 0 then
			entity:ModifyStat("Mana", manaRegenPerSecond * dt)
		end

		local staminaRegenPerSecond = GetStaminaRegenPerSecond(entity, state, now)
		if staminaRegenPerSecond > 0 then
			entity:ModifyStat("Stamina", staminaRegenPerSecond * dt)
		end
	end
end)

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	local entity = PlayerCharacters[player.Name]
	if action == "RequestSnapshot" then
		if entity then
			SyncStatsToClient(player, entity)
		end
	elseif action == "RequestDashIFrames" then
		if not entity or not entity:IsAlive() then
			return
		end

		local state = GetRuntimeState(player.Name)
		StopRunning(entity, state)

		local now = workspace:GetServerTimeNow()
		if now < (PlayerNextDashIframeAt[player.Name] or 0) then
			return
		end

		local humanoid = entity.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.FloorMaterial == Enum.Material.Air then
			return
		end

		if not TryConsumeStamina(entity, DASH_STAMINA_COST) then
			return
		end

		PlayerNextDashIframeAt[player.Name] = now + DASH_IFRAME_COOLDOWN
		state.DashUntil = now + DASH_IFRAME_DURATION
		state.RunningEligibleUntil = math.huge
		BeginStaminaRamp(state, state.DashUntil)
		entity:SetInvincibleFor(DASH_IFRAME_DURATION)
	elseif action == "SetRightClickHeld" then
		if not entity then
			return
		end

		local state = GetRuntimeState(player.Name)
		state.IsRightClickHeld = true
	elseif action == "SetRightClickReleased" then
		if not entity then
			return
		end

		local state = GetRuntimeState(player.Name)
		state.IsRightClickHeld = false
		state.RunLockedUntilRelease = false
		local wasRunning = state.IsRunning
		StopRunning(entity, state)
		if wasRunning then
			BeginStaminaRamp(state, workspace:GetServerTimeNow())
		end
	elseif action == "DebugTakeDamage" then
		if not RunService:IsStudio() or not entity or not entity:IsAlive() then
			return
		end

		local amount = if payload and type(payload.Amount) == "number" then payload.Amount else 10
		entity:ModifyStat("Health", -math.max(0, amount))
	elseif action == "DebugGrantAllNonConsumableItems" then
		if not RunService:IsStudio() then
			return
		end

		debugGrantAllNonConsumableItems(player)
	elseif action == "DebugGrantAllWeapons" then
		if not RunService:IsStudio() then
			return
		end

		debugGrantAllWeapons(player)
	end
end)

-- Method that returns list of players for use in
-- other Services
function PlayerServiceServer.GetPlayers(): { [string]: Entity }
	return PlayerCharacters
end

function PlayerServiceServer.GetEntity(player: Player): Entity?
	return PlayerCharacters[player.Name]
end

function PlayerServiceServer.GetEntityFromCharacter(character: Model): Entity?
	for _, entity in pairs(PlayerCharacters) do
		if entity.Character == character then
			return entity
		end
	end

	return nil
end

function PlayerServiceServer.CanStartPrimaryAttack(player: Player, isHeavy: boolean, noStamina: boolean): boolean
	local entity = PlayerCharacters[player.Name]
	if not entity or not entity:IsAlive() then
		return false
	end

	if noStamina then
		return true
	end

	return entity:GetStat("Stamina") >= GetAttackStaminaCost(entity, isHeavy, noStamina)
end

function PlayerServiceServer.RegisterPrimaryAttack(player: Player, clearAt: number, isHeavy: boolean, noStamina: boolean)
	local entity = PlayerCharacters[player.Name]
	if not entity then
		return false
	end

	local state = GetRuntimeState(player.Name)
	StopRunning(entity, state)
	state.AttackUntil = clearAt
	state.RunningEligibleUntil = 0

	if not noStamina then
		if not TryConsumeStat(entity, "Stamina", GetAttackStaminaCost(entity, isHeavy, noStamina)) then
			return false
		end
	end

	if isHeavy then
		state.IsHeavyAttackActive = true
		state.HeavyAttackUntil = clearAt
		BeginStaminaRamp(state, clearAt)
	else
		state.IsHeavyAttackActive = false
	end

	return true
end

return table.freeze(PlayerServiceServer)
