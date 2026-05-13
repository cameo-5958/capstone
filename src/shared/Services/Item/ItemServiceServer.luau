--!strict

local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Damage = require(ReplicatedStorage.Classes.Attack.Damage)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local ItemTypes = require(ReplicatedStorage.Classes.Item.ItemTypes)
local ItemRegistry = require(ReplicatedStorage.Database.Items.Registry)
local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local WorldServiceServer = require(ReplicatedStorage.Services.World.WorldServiceServer)

type Entity = EntityTypes.Entity
type InventoryEntry = InventoryServiceServer.InventoryEntry
type ItemDefinition = ItemTypes.ItemDefinition
type ItemEffect = ItemTypes.ItemEffect
type ItemModifier = ItemTypes.ItemModifier
type SerializedItemData = ItemTypes.SerializedItemData

type TimedEffect = {
	Id: string,
	EndsAt: number,
	NextTickAt: number,
	TickRate: number,
	MaxTicksPerStep: number,
	Tick: () -> (),
	OnEnd: (() -> ())?,
}

type ContactZone = {
	Id: string,
	Caster: Entity,
	Center: Vector3,
	Radius: number,
	DamagePerTick: number,
	Modifiers: { ItemModifier },
	Source: string,
	EndsAt: number,
	NextTickAt: number,
	TickRate: number,
	ContactDuration: number,
	AffectedTargets: { [string]: Entity },
	ContactExpiresAt: { [string]: number },
}

type FlagBoostZone = {
	Id: string,
	ItemId: string,
	Source: string,
	Center: Vector3,
	Radius: number,
	Modifiers: { ItemModifier },
	HealPercentPerTick: number,
	TickRate: number,
	RefreshDuration: number,
	NextTickAt: number,
	EndsAt: number,
	AccentColor: Color3,
	PulseInterval: number,
	NextPulseAt: number,
	Forward: Vector3,
	Right: Vector3,
	AnchorTileX: number?,
	AnchorTileZ: number?,
	AnchorSeed: number?,
	VisualModel: Model?,
}

type FlagPlayerEffectState = {
	Entity: Entity,
	ExpiresAt: number,
}

local endpoint = script.Parent:FindFirstChild("ItemEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "ItemEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent
local ItemServiceServer = {}

local SeededPlayers: { [Player]: boolean } = {}
local ActiveTimedEffects: { TimedEffect } = {}
local ActiveContactZones: { ContactZone } = {}
local ActiveFlagBoostZones: { FlagBoostZone } = {}
local ActiveFlagEffectsByPlayerAndSource: { [string]: { [string]: FlagPlayerEffectState } } = {}
local FlagVisualRoot: Folder? = nil

local DEFAULT_TICK_RATE = 1
local DEFAULT_MAX_TICKS_PER_STEP = 4
local FLAG_DEFAULT_DURATION = 30
local FLAG_DEFAULT_RADIUS = 15
local FLAG_DEFAULT_PULSE_INTERVAL = 1
local FLAG_DEFAULT_TICK_RATE = 0.5
local FLAG_DEFAULT_REFRESH_DURATION = 1
local FLAG_PULSE_SEGMENTS = 20
local FLAG_PULSE_DURATION = 0.85
local FLAG_GROUND_OFFSET = 0.45
local FLAG_PULSE_HEIGHT = 0.6
local FLAG_DEFAULT_COLOR = Color3.fromRGB(212, 70, 52)
local FLAG_RANGE_COLOR = Color3.fromRGB(155, 210, 255)
local FLAG_RANGE_TRANSPARENCY = 0.93

local function now(): number
	return workspace:GetServerTimeNow()
end

local function cloneSerializable(value: any): any
	local valueType = type(value)
	if valueType == "table" then
		local clone = {}
		for key, child in pairs(value) do
			local keyType = type(key)
			if keyType == "string" or keyType == "number" then
				local clonedChild = cloneSerializable(child)
				if clonedChild ~= nil then
					clone[key] = clonedChild
				end
			end
		end
		return clone
	elseif valueType == "string" or valueType == "number" or valueType == "boolean" then
		return value
	end

	local robloxType = typeof(value)
	if robloxType == "Vector3" or robloxType == "Vector2" or robloxType == "Color3" or robloxType == "CFrame" then
		return value
	end

	return nil
end

local function hasFlag(effect: ItemEffect, flag: string): boolean
	if type(effect.Flags) ~= "table" then
		return false
	end

	for _, value in ipairs(effect.Flags) do
		if value == flag then
			return true
		end
	end

	return false
end

local function getEffectNumber(effect: ItemEffect, key: string, fallback: number): number
	local value = (effect :: any)[key]
	if type(value) ~= "number" then
		return fallback
	end
	return value
end

local function getEffectModifiers(effect: ItemEffect): { ItemModifier }
	if type(effect.Modifiers) ~= "table" then
		return {}
	end
	return effect.Modifiers
end

local function getClosestEnemy(sourcePosition: Vector3, range: number): Entity?
	return EnemyServiceServer.GetClosest(sourcePosition, range)
end

local function getEnemiesInRadius(sourcePosition: Vector3, radius: number): { Entity }
	local enemies = EnemyServiceServer.GetInRadius(sourcePosition, radius)
	if type(enemies) == "table" then
		return enemies
	end
	return {}
end

local function flattenUnit(vector: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return fallback
	end
	return flat.Unit
end

local function ensureFlagVisualRoot(): Folder
	if FlagVisualRoot and FlagVisualRoot.Parent then
		return FlagVisualRoot
	end

	local parent: Instance = Workspace
	local worldFolder = Workspace:FindFirstChild("WorldService")
	if worldFolder then
		local visualRoot = worldFolder:FindFirstChild("VisualRoot")
		if visualRoot and visualRoot:IsA("Folder") then
			parent = visualRoot
		end
	end

	local existing = parent:FindFirstChild("ItemFlags")
	if existing and existing:IsA("Folder") then
		FlagVisualRoot = existing
		return existing
	end

	local created = Instance.new("Folder")
	created.Name = "ItemFlags"
	created.Parent = parent
	FlagVisualRoot = created
	return created
end

local function buildFlagVisual(itemId: string, center: Vector3, forward: Vector3, radius: number, accentColor: Color3): Model
	local visualRoot = ensureFlagVisualRoot()
	local forwardUnit = flattenUnit(forward, Vector3.new(0, 0, -1))
	local orientation = CFrame.lookAt(center, center + forwardUnit, Vector3.new(0, 1, 0))

	local model = Instance.new("Model")
	model.Name = itemId

	local rangeDisc = Instance.new("Part")
	rangeDisc.Name = "Range"
	rangeDisc.Anchored = true
	rangeDisc.CanCollide = false
	rangeDisc.CanTouch = false
	rangeDisc.CanQuery = false
	rangeDisc.Material = Enum.Material.Neon
	rangeDisc.Shape = Enum.PartType.Cylinder
	rangeDisc.Color = FLAG_RANGE_COLOR
	rangeDisc.Transparency = FLAG_RANGE_TRANSPARENCY
	rangeDisc.Size = Vector3.new(0.3, radius * 2, radius * 2)
	rangeDisc.CFrame = CFrame.new(center + Vector3.new(0, FLAG_GROUND_OFFSET, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rangeDisc.Parent = model

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CanQuery = false
	base.Material = Enum.Material.Slate
	base.Color = Color3.fromRGB(90, 90, 95)
	base.Size = Vector3.new(0.9, 0.35, 0.9)
	base.CFrame = orientation * CFrame.new(0, 0.175, 0)
	base.Parent = model

	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Anchored = true
	pole.CanCollide = false
	pole.CanTouch = false
	pole.CanQuery = false
	pole.Material = Enum.Material.Wood
	pole.Color = Color3.fromRGB(90, 66, 42)
	pole.Size = Vector3.new(0.2, 5.8, 0.2)
	pole.CFrame = orientation * CFrame.new(0, 3.1, 0)
	pole.Parent = model

	local banner = Instance.new("Part")
	banner.Name = "Banner"
	banner.Anchored = true
	banner.CanCollide = false
	banner.CanTouch = false
	banner.CanQuery = false
	banner.Material = Enum.Material.Fabric
	banner.Color = accentColor
	banner.Size = Vector3.new(0.2, 2.6, 1.7)
	banner.CFrame = orientation * CFrame.new(0.29, 4.25, 0)
	banner.Parent = model

	local topper = Instance.new("Part")
	topper.Name = "Topper"
	topper.Anchored = true
	topper.CanCollide = false
	topper.CanTouch = false
	topper.CanQuery = false
	topper.Material = Enum.Material.Metal
	topper.Color = Color3.fromRGB(235, 197, 110)
	topper.Shape = Enum.PartType.Ball
	topper.Size = Vector3.new(0.3, 0.3, 0.3)
	topper.CFrame = orientation * CFrame.new(0, 6.1, 0)
	topper.Parent = model

	model.PrimaryPart = base
	model.Parent = visualRoot
	return model
end

local function spawnFlagPulse(zone: FlagBoostZone)
	local zoneVisual = zone.VisualModel
	if not zoneVisual or not zoneVisual.Parent then
		return
	end

	local pulseFolder = Instance.new("Folder")
	pulseFolder.Name = "Pulse"
	pulseFolder.Parent = zoneVisual

	local startRadius = math.min(2, zone.Radius * 0.2)
	for index = 0, FLAG_PULSE_SEGMENTS - 1 do
		local alpha = index / FLAG_PULSE_SEGMENTS
		local theta = alpha * math.pi * 2
		local direction = zone.Right * math.cos(theta) + zone.Forward * math.sin(theta)
		if direction.Magnitude <= 0.001 then
			continue
		end

		local dirUnit = direction.Unit
		local segment = Instance.new("Part")
		segment.Name = "PulseSegment"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = false
		segment.Material = Enum.Material.Neon
		segment.Color = zone.AccentColor
		segment.Shape = Enum.PartType.Ball
		segment.Size = Vector3.new(0.48, 0.48, 0.48)
		segment.Transparency = 0.08
		segment.Position = zone.Center + dirUnit * startRadius + Vector3.new(0, FLAG_PULSE_HEIGHT, 0)
		segment.Parent = pulseFolder

		local goal = {
			Position = zone.Center + dirUnit * zone.Radius + Vector3.new(0, FLAG_PULSE_HEIGHT, 0),
			Transparency = 1,
			Size = Vector3.new(0.22, 0.22, 0.22),
		}
		TweenService:Create(
			segment,
			TweenInfo.new(FLAG_PULSE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		):Play()
		Debris:AddItem(segment, FLAG_PULSE_DURATION + 0.2)
	end

	Debris:AddItem(pulseFolder, FLAG_PULSE_DURATION + 0.3)
end

local function resolveFlagPlacement(origin: Vector3): (Vector3?, number?, number?, number?)
	local world = WorldServiceServer.GetWorld() :: any
	if not world or type(world) ~= "table" then
		return origin, nil, nil, nil
	end

	local config = world.Config
	if type(config) ~= "table" or type(config.TileSize) ~= "number" or config.TileSize <= 0 then
		return origin, nil, nil, WorldServiceServer.GetSeed()
	end

	local tileSize = config.TileSize
	local tileX = math.floor(origin.X / tileSize + 0.5)
	local tileZ = math.floor(origin.Z / tileSize + 0.5)
	local tile = WorldServiceServer.GetTile(tileX, tileZ) :: any
	if not tile or not tile.Solid then
		return nil, nil, nil, nil
	end

	return Vector3.new(tile.X * tileSize, tile.SurfaceY, tile.Z * tileSize), tileX, tileZ, WorldServiceServer.GetSeed()
end

local function isFlagAnchorValid(zone: FlagBoostZone): boolean
	if zone.AnchorSeed and zone.AnchorSeed ~= WorldServiceServer.GetSeed() then
		return false
	end

	if zone.AnchorTileX == nil or zone.AnchorTileZ == nil then
		return true
	end

	local tile = WorldServiceServer.GetTile(zone.AnchorTileX, zone.AnchorTileZ) :: any
	return tile ~= nil and tile.Solid == true
end

local function destroyFlagZone(zone: FlagBoostZone)
	if zone.VisualModel and zone.VisualModel.Parent then
		zone.VisualModel:Destroy()
	end
	zone.VisualModel = nil
end

local function serializeItem(item: ItemDefinition): SerializedItemData
	local stackKey = item.StackKey or ("Item:" .. item.Id)
	return {
		Kind = "Item",
		ItemId = item.Id,
		Name = item.Name,
		Desc = item.Desc,
		Icon = item.Icon,
		MaxStack = math.max(1, math.floor(item.MaxStack)),
		SpawnWith = math.max(0, math.floor(item.SpawnWith)),
		StackKey = stackKey,
		InventoryData = cloneSerializable(item.InventoryData) or {},
		Effects = cloneSerializable(item.Effects) or {},
	}
end

local function addTimedEffect(duration: number, tickRate: number, onTick: () -> (), onEnd: (() -> ())?)
	local tick = math.max(0.05, tickRate)
	local startAt = now()
	local effect: TimedEffect = {
		Id = HttpService:GenerateGUID(false),
		EndsAt = startAt + math.max(0.05, duration),
		NextTickAt = startAt,
		TickRate = tick,
		MaxTicksPerStep = DEFAULT_MAX_TICKS_PER_STEP,
		Tick = onTick,
		OnEnd = onEnd,
	}
	table.insert(ActiveTimedEffects, effect)
end

local function applyTemporaryModifiers(target: Entity, source: string, modifiers: { ItemModifier })
	for index, modifier in ipairs(modifiers) do
		local statName = modifier.Stat
		local modifierValue = modifier.Value
		local modifierType = modifier.ModifierType
		target:AddModifier(statName, Modifier.new(
			string.format("%s:%s:%d", source, statName, index),
			modifierType,
			modifierValue,
			source
		))
	end
end

local function createContactZone(
	caster: Entity,
	effect: ItemEffect,
	origin: Vector3,
	source: string
): boolean
	local duration = getEffectNumber(effect, "Duration", 4)
	local tickRate = getEffectNumber(effect, "TickRate", 0.5)
	local radius = math.max(0.1, getEffectNumber(effect, "Radius", 8))
	local damagePerTick = getEffectNumber(effect, "DamagePerTick", 0)
	local modifiers = getEffectModifiers(effect)
	if damagePerTick <= 0 and #modifiers <= 0 then
		return false
	end

	table.insert(ActiveContactZones, {
		Id = HttpService:GenerateGUID(false),
		Caster = caster,
		Center = origin,
		Radius = radius,
		DamagePerTick = damagePerTick,
		Modifiers = modifiers,
		Source = source,
		EndsAt = now() + math.max(0.05, duration),
		NextTickAt = now(),
		TickRate = math.max(0.05, tickRate),
		ContactDuration = math.max(0.05, getEffectNumber(effect, "ContactModifierDuration", 0.6)),
		AffectedTargets = {},
		ContactExpiresAt = {},
	})

	return true
end

local function createFlagBoostZone(caster: Entity, itemId: string, effectIndex: number, effect: ItemEffect): boolean
	local duration = math.max(0.05, getEffectNumber(effect, "Duration", FLAG_DEFAULT_DURATION))
	local radius = math.max(0.1, getEffectNumber(effect, "Radius", FLAG_DEFAULT_RADIUS))
	local pulseInterval = math.max(0.5, getEffectNumber(effect, "PulseInterval", FLAG_DEFAULT_PULSE_INTERVAL))
	local tickRate = math.max(0.05, getEffectNumber(effect, "TickRate", FLAG_DEFAULT_TICK_RATE))
	local refreshDuration = math.max(0.05, getEffectNumber(effect, "ContactModifierDuration", FLAG_DEFAULT_REFRESH_DURATION))
	local healPercentPerTick = math.max(0, getEffectNumber(effect, "HealPercentPerTick", 0))
	local modifiers = getEffectModifiers(effect)
	if #modifiers <= 0 and healPercentPerTick <= 0 then
		return false
	end

	local placementRange = getEffectNumber(effect, "Range", 0)
	local offsetVector = if typeof(effect.Offset) == "Vector3" then effect.Offset else Vector3.zero
	local accentColor = if typeof(effect.Color) == "Color3" then effect.Color else FLAG_DEFAULT_COLOR
	local forward = flattenUnit(caster.RootPart.CFrame.LookVector, Vector3.new(0, 0, -1))
	local right = flattenUnit(forward:Cross(Vector3.new(0, 1, 0)), Vector3.new(1, 0, 0))
	local origin = caster.RootPart.Position + forward * placementRange + offsetVector
	local center, tileX, tileZ, seed = resolveFlagPlacement(origin)
	if center == nil then
		return false
	end

	local zone: FlagBoostZone = {
		Id = HttpService:GenerateGUID(false),
		ItemId = itemId,
		Source = string.format("item:flagboost:%s:%d", itemId, effectIndex),
		Center = center,
		Radius = radius,
		Modifiers = modifiers,
		HealPercentPerTick = healPercentPerTick,
		TickRate = tickRate,
		RefreshDuration = refreshDuration,
		NextTickAt = now(),
		EndsAt = now() + duration,
		AccentColor = accentColor,
		PulseInterval = pulseInterval,
		NextPulseAt = now() + pulseInterval,
		Forward = forward,
		Right = right,
		AnchorTileX = tileX,
		AnchorTileZ = tileZ,
		AnchorSeed = seed,
		VisualModel = buildFlagVisual(itemId, center, forward, radius, accentColor),
	}

	table.insert(ActiveFlagBoostZones, zone)
	spawnFlagPulse(zone)
	return true
end

local function resolveSerializedItem(entry: InventoryEntry): SerializedItemData?
	if entry.ItemKind ~= "Item" then
		return nil
	end

	local data = entry.Data
	if type(data) ~= "table" then
		return nil
	end

	if data.Kind == "Item" and type(data.ItemId) == "string" and data.ItemId ~= "" then
		if type(data.Effects) == "table" and #data.Effects > 0 then
			return data :: SerializedItemData
		end

		local upgradedDefinition = ItemRegistry.Get(data.ItemId)
		if upgradedDefinition then
			return serializeItem(upgradedDefinition)
		end
	end

	local itemId = data.ItemId
	if type(itemId) ~= "string" or itemId == "" then
		return nil
	end

	local definition = ItemRegistry.Get(itemId)
	if not definition then
		return nil
	end

	return serializeItem(definition)
end

local function applyEffect(player: Player, caster: Entity, itemData: SerializedItemData, effect: ItemEffect, effectIndex: number): boolean
	local effectSource = string.format("item:%s:%s:%d:%s", itemData.ItemId, player.UserId, effectIndex, HttpService:GenerateGUID(false))

	if effect.Kind == "HealOverTime" or (effect.Kind == "Heal" and hasFlag(effect, "AffectOverTime")) then
		local amountPerTick = getEffectNumber(effect, "AmountPerTick", getEffectNumber(effect, "Amount", 0))
		local duration = getEffectNumber(effect, "Duration", 4)
		local tickRate = getEffectNumber(effect, "TickRate", DEFAULT_TICK_RATE)
		if amountPerTick <= 0 or duration <= 0 then
			return false
		end
		addTimedEffect(duration, tickRate, function()
			if caster:IsAlive() then
				caster:ModifyStat("Health", amountPerTick)
			end
		end, nil)
		return true
	end

	if effect.Kind == "Heal" then
		local amount = getEffectNumber(effect, "Amount", 0)
		if amount <= 0 then
			return false
		end
		caster:ModifyStat("Health", amount)
		return true
	end

	if effect.Kind == "DamageOverTime" then
		local range = getEffectNumber(effect, "Range", 26)
		local target = getClosestEnemy(caster.RootPart.Position, range)
		if not target or not target:IsAlive() then
			return false
		end

		local duration = getEffectNumber(effect, "Duration", 4)
		local tickRate = getEffectNumber(effect, "TickRate", DEFAULT_TICK_RATE)
		local damagePerTick = getEffectNumber(effect, "DamagePerTick", 0)
		if damagePerTick <= 0 or duration <= 0 then
			return false
		end

		addTimedEffect(duration, tickRate, function()
			if caster:IsAlive() and target:IsAlive() then
				Damage.TrueDamage(caster, target, damagePerTick)
			end
		end, nil)
		return true
	end

	if effect.Kind == "SelfBuff" then
		local duration = getEffectNumber(effect, "Duration", 6)
		local modifiers = getEffectModifiers(effect)
		if duration <= 0 or #modifiers <= 0 then
			return false
		end

		applyTemporaryModifiers(caster, effectSource, modifiers)
		addTimedEffect(duration, duration, function() end, function()
			caster:RemoveModifiersFromSource(effectSource)
		end)
		return true
	end

	if effect.Kind == "FlagBoost" then
		return createFlagBoostZone(caster, itemData.ItemId, effectIndex, effect)
	end

	if effect.Kind == "Tornado" or effect.Kind == "ApplyModifierOnContact" or hasFlag(effect, "OnContact") then
		local range = getEffectNumber(effect, "Range", 0)
		local offsetVector = if typeof(effect.Offset) == "Vector3" then effect.Offset else Vector3.zero
		local center = caster.RootPart.Position + caster.RootPart.CFrame.LookVector * range + offsetVector
		return createContactZone(caster, effect, center, effectSource)
	end

	return false
end

local function useInventoryEntry(player: Player, entryId: string): (boolean, string)
	if type(entryId) ~= "string" or entryId == "" then
		return false, "InvalidEntry"
	end

	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity:IsAlive() then
		return false, "NoEntity"
	end

	local entry = InventoryServiceServer.GetEntry(player, entryId)
	if not entry or entry.ItemKind ~= "Item" then
		return false, "NotItem"
	end

	local itemData = resolveSerializedItem(entry)
	if not itemData then
		return false, "InvalidItemData"
	end

	if type(itemData.Effects) ~= "table" or #itemData.Effects <= 0 then
		return false, "NoEffects"
	end

	local appliedAny = false
	for index, effect in ipairs(itemData.Effects :: { ItemEffect }) do
		local didApply = applyEffect(player, entity, itemData, effect, index)
		appliedAny = appliedAny or didApply
	end

	if not appliedAny then
		return false, "NoValidEffect"
	end

	local removed = InventoryServiceServer.RemoveEntry(player, entryId, 1)
	if not removed then
		return false, "FailedToConsume"
	end

	return true, "Used"
end

local function seedSpawnItems(player: Player)
	if SeededPlayers[player] then
		return
	end

	SeededPlayers[player] = true
	for _, item in ipairs(ItemRegistry.GetSpawnableItems()) do
		local serialized = serializeItem(item)
		InventoryServiceServer.AddStackableItem(
			player,
			"Item",
			serialized.StackKey,
			serialized :: any,
			serialized.SpawnWith,
			serialized.MaxStack
		)
	end
end

local function stepTimedEffects(currentTime: number)
	for index = #ActiveTimedEffects, 1, -1 do
		local effect = ActiveTimedEffects[index]
		local ticks = 0
		while currentTime >= effect.NextTickAt and currentTime <= effect.EndsAt and ticks < effect.MaxTicksPerStep do
			effect.Tick()
			effect.NextTickAt += effect.TickRate
			ticks += 1
		end

		if currentTime >= effect.EndsAt then
			if effect.OnEnd then
				effect.OnEnd()
			end
			table.remove(ActiveTimedEffects, index)
		end
	end
end

local function stepContactZones(currentTime: number)
	for index = #ActiveContactZones, 1, -1 do
		local zone = ActiveContactZones[index]
		if currentTime >= zone.EndsAt or not zone.Caster:IsAlive() then
			for _, target in pairs(zone.AffectedTargets) do
				if target and target:IsAlive() then
					target:RemoveModifiersFromSource(zone.Source)
				end
			end
			table.remove(ActiveContactZones, index)
			continue
		end

		if currentTime < zone.NextTickAt then
			continue
		end

		zone.NextTickAt = currentTime + zone.TickRate
		for _, target in ipairs(getEnemiesInRadius(zone.Center, zone.Radius)) do
			if target:IsAlive() then
				if zone.DamagePerTick > 0 then
					Damage.TrueDamage(zone.Caster, target, zone.DamagePerTick)
				end

				if #zone.Modifiers > 0 then
					if zone.AffectedTargets[target.UUID] == nil then
						zone.AffectedTargets[target.UUID] = target
						applyTemporaryModifiers(target, zone.Source, zone.Modifiers)
					end
					zone.ContactExpiresAt[target.UUID] = currentTime + zone.ContactDuration
				end
			end
		end

		for targetUUID, expireAt in pairs(zone.ContactExpiresAt) do
			if currentTime >= expireAt then
				local target = zone.AffectedTargets[targetUUID]
				if target then
					target:RemoveModifiersFromSource(zone.Source)
				end
				zone.AffectedTargets[targetUUID] = nil
				zone.ContactExpiresAt[targetUUID] = nil
			end
		end
	end
end

local function stepFlagBoostZones(currentTime: number)
	for index = #ActiveFlagBoostZones, 1, -1 do
		local zone = ActiveFlagBoostZones[index]
		if currentTime >= zone.EndsAt or not isFlagAnchorValid(zone) then
			destroyFlagZone(zone)
			table.remove(ActiveFlagBoostZones, index)
			continue
		end

		if currentTime >= zone.NextPulseAt then
			zone.NextPulseAt = currentTime + zone.PulseInterval
			spawnFlagPulse(zone)
		end

		if currentTime >= zone.NextTickAt then
			zone.NextTickAt = currentTime + zone.TickRate
			for _, playerEntity in pairs(PlayerServiceServer.GetPlayers()) do
				if not playerEntity:IsAlive() then
					continue
				end

				local position = playerEntity.RootPart.Position
				local dx = position.X - zone.Center.X
				local dz = position.Z - zone.Center.Z
				local distanceSq = dx * dx + dz * dz
				if distanceSq > zone.Radius * zone.Radius then
					continue
				end

				if zone.HealPercentPerTick > 0 then
					local healAmount = playerEntity:GetStat("MaxHealth") * zone.HealPercentPerTick
					if healAmount > 0 then
						playerEntity:ModifyStat("Health", healAmount)
					end
				end

				if #zone.Modifiers > 0 then
					applyTemporaryModifiers(playerEntity, zone.Source, zone.Modifiers)
					local bySource = ActiveFlagEffectsByPlayerAndSource[playerEntity.UUID]
					if bySource == nil then
						bySource = {}
						ActiveFlagEffectsByPlayerAndSource[playerEntity.UUID] = bySource
					end
					bySource[zone.Source] = {
						Entity = playerEntity,
						ExpiresAt = currentTime + zone.RefreshDuration,
					}
				end
			end
		end
	end

	for playerUUID, bySource in pairs(ActiveFlagEffectsByPlayerAndSource) do
		for source, state in pairs(bySource) do
			if currentTime >= state.ExpiresAt or not state.Entity:IsAlive() then
				state.Entity:RemoveModifiersFromSource(source)
				bySource[source] = nil
			end
		end

		if next(bySource) == nil then
			ActiveFlagEffectsByPlayerAndSource[playerUUID] = nil
		end
	end
end

RunService.Heartbeat:Connect(function()
	local currentTime = now()
	stepTimedEffects(currentTime)
	stepContactZones(currentTime)
	stepFlagBoostZones(currentTime)
end)

function ItemServiceServer.init(): ()
	for _, player in ipairs(Players:GetPlayers()) do
		seedSpawnItems(player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			seedSpawnItems(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		SeededPlayers[player] = nil

		local playerEntity = PlayerServiceServer.GetEntity(player)
		if not playerEntity then
			return
		end

		local bySource = ActiveFlagEffectsByPlayerAndSource[playerEntity.UUID]
		if bySource then
			for source in pairs(bySource) do
				playerEntity:RemoveModifiersFromSource(source)
			end
			ActiveFlagEffectsByPlayerAndSource[playerEntity.UUID] = nil
		end
	end)
end

function ItemServiceServer.GetSerializedItem(itemId: string): SerializedItemData?
	local definition = ItemRegistry.Get(itemId)
	if not definition then
		return nil
	end
	return serializeItem(definition)
end

function ItemServiceServer.AddItemToInventory(player: Player, itemId: string, quantity: number): { string }
	local definition = ItemRegistry.Get(itemId)
	if not definition then
		return {}
	end

	local serialized = serializeItem(definition)
	return InventoryServiceServer.AddStackableItem(
		player,
		"Item",
		serialized.StackKey,
		serialized :: any,
		math.max(0, math.floor(quantity)),
		serialized.MaxStack
	)
end

function ItemServiceServer.UseInventoryEntry(player: Player, entryId: string): boolean
	local ok, reason = useInventoryEntry(player, entryId)
	API:FireClient(player, "UseResult", {
		EntryId = entryId,
		Success = ok,
		Reason = reason,
	})
	return ok
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "UseInventoryEntry" then
		local entryId = payload and payload.EntryId
		if type(entryId) == "string" then
			ItemServiceServer.UseInventoryEntry(player, entryId)
		end
	elseif action == "RequestCatalog" then
		local serializedCatalog = {}
		for itemId, definition in pairs(ItemRegistry.GetAll()) do
			serializedCatalog[itemId] = serializeItem(definition)
		end
		API:FireClient(player, "Catalog", serializedCatalog)
	end
end)

return table.freeze(ItemServiceServer)
