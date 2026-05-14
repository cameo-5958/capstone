--!strict

local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Damage = require(ReplicatedStorage.Classes.Attack.Damage)
local Modifier = require(ReplicatedStorage.Classes.Modifier.Modifier)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local ItemTypes = require(ReplicatedStorage.Classes.Item.ItemTypes)
local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)

type Entity = EntityTypes.Entity
type ItemModifier = ItemTypes.ItemModifier
type TargetGroup = "Enemies" | "Players"

export type TornadoZone = {
	Id: string,
	Caster: Entity,
	Center: Vector3,
	PullTarget: Vector3,
	Radius: number,
	Source: string,
	TargetGroup: TargetGroup,
	IncludeCaster: boolean,
	EndsAt: number,
	NextTickAt: number,
	TickRate: number,
	DamagePerTick: number,
	Modifiers: { ItemModifier },
	ContactDuration: number,
	PullSpeed: number,
	MinPullSpeed: number,
	MaxResultantSpeed: number,
	LiftVelocity: number,
	DeadzoneRadius: number,
	AffectedTargets: { [string]: Entity },
	ContactExpiresAt: { [string]: number },
	OnTickTarget: ((Entity, Entity, TornadoZone) -> ())?,
	VisualParts: { BasePart },
	VisualStartedAt: number,
}

export type TornadoOptions = {
	Center: Vector3,
	Radius: number?,
	Range: number?,
	Duration: number?,
	TickRate: number?,
	DamagePerTick: number?,
	Modifiers: { ItemModifier }?,
	ContactModifierDuration: number?,
	PullSpeed: number?,
	MinPullSpeed: number?,
	MaxResultantSpeed: number?,
	LiftVelocity: number?,
	DeadzoneRadius: number?,
	PullHeight: number?,
	TargetGroup: TargetGroup?,
	IncludeCaster: boolean?,
	Source: string?,
	OnTickTarget: ((Entity, Entity, TornadoZone) -> ())?,
}

local SpellServiceServer = {}

local DEFAULT_TORNADO_RADIUS = 10
local DEFAULT_TORNADO_DURATION = 4
local DEFAULT_TORNADO_TICK_RATE = 0.5
local DEFAULT_TORNADO_PULL_SPEED = 24
local DEFAULT_TORNADO_MIN_PULL_SPEED = 8
local DEFAULT_TORNADO_MAX_RESULTANT_SPEED = 42
local DEFAULT_TORNADO_CONTACT_DURATION = 0.6
local DEFAULT_TORNADO_LIFT_VELOCITY = 0
local DEFAULT_TORNADO_DEADZONE_RADIUS = 1.75
local DEFAULT_TORNADO_PULL_HEIGHT = 9
local SPELL_LINEAR_VELOCITY_NAME = "SpellLinearVelocity"
local TORNADO_VISUAL_PART_COUNT = 14
local TORNADO_VISUAL_NAME = "TornadoVisual"
local TORNADO_VISUAL_COLOR = Color3.fromRGB(146, 183, 178)
local TORNADO_VISUAL_HEIGHT_WAVE = 1.5
local TORNADO_VISUAL_ROTATION_SPEED = 4.5
local TORNADO_VISUAL_INWARD_DRIFT = 0.55

local ActiveTornadoZones: { TornadoZone } = {}
local EntitiesWithSpellVelocity: { [Entity]: true } = {}
local SpellVisualRoot: Folder? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function applyTemporaryModifiers(target: Entity, source: string, modifiers: { ItemModifier })
	for index, modifier in ipairs(modifiers) do
		target:AddModifier(
			modifier.Stat,
			Modifier.new(
				string.format("%s:%s:%d", source, modifier.Stat, index),
				modifier.ModifierType,
				modifier.Value,
				source
			)
		)
	end
end

local function ensureSpellVisualRoot(): Folder
	if SpellVisualRoot and SpellVisualRoot.Parent then
		return SpellVisualRoot
	end

	local parent: Instance = Workspace
	local worldFolder = Workspace:FindFirstChild("WorldService")
	if worldFolder then
		local visualRoot = worldFolder:FindFirstChild("VisualRoot")
		if visualRoot and visualRoot:IsA("Folder") then
			parent = visualRoot
		end
	end

	local existing = parent:FindFirstChild("SpellVisuals")
	if existing and existing:IsA("Folder") then
		SpellVisualRoot = existing
		return existing
	end

	local created = Instance.new("Folder")
	created.Name = "SpellVisuals"
	created.Parent = parent
	SpellVisualRoot = created
	return created
end

local function createTornadoVisualPart(index: number, zone: TornadoZone): BasePart
	local random = Random.new(index * 193 + math.floor(zone.Center.X) + math.floor(zone.Center.Z))
	local size = random:NextNumber(0.8, 1.8)

	local part = Instance.new("Part")
	part.Name = string.format("%s_%d", TORNADO_VISUAL_NAME, index)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = TORNADO_VISUAL_COLOR
	part.Transparency = 0.95
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(zone.Center)
	part.Parent = ensureSpellVisualRoot()

	TweenService:Create(
		part,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 0.08 }
	):Play()

	return part
end

local function createTornadoVisual(zone: TornadoZone): { BasePart }
	local parts = {}
	for index = 1, TORNADO_VISUAL_PART_COUNT do
		table.insert(parts, createTornadoVisualPart(index, zone))
	end
	return parts
end

local function updateTornadoVisual(zone: TornadoZone, currentTime: number)
	local totalDuration = math.max(zone.EndsAt - zone.VisualStartedAt, 0.001)
	local lifeAlpha = math.clamp((currentTime - zone.VisualStartedAt) / totalDuration, 0, 1)

	for index, part in ipairs(zone.VisualParts) do
		if not part or part.Parent == nil then
			continue
		end

		local indexAlpha = index / math.max(#zone.VisualParts, 1)
		local orbitAlpha = (currentTime - zone.VisualStartedAt) * TORNADO_VISUAL_ROTATION_SPEED + indexAlpha * math.pi * 2
		local spiralAlpha = (((currentTime - zone.VisualStartedAt) * TORNADO_VISUAL_INWARD_DRIFT) + indexAlpha) % 1
		local radius = math.max(1.2, zone.Radius * (1 - spiralAlpha))
		local x = math.cos(orbitAlpha) * radius
		local z = math.sin(orbitAlpha) * radius
		local ySpan = zone.PullTarget.Y - zone.Center.Y
		local y = zone.Center.Y + spiralAlpha * ySpan + math.sin(orbitAlpha * 1.8) * TORNADO_VISUAL_HEIGHT_WAVE
		part.CFrame = CFrame.new(zone.Center + Vector3.new(x, y - zone.Center.Y, z))
			* CFrame.Angles(orbitAlpha * 0.7, orbitAlpha, orbitAlpha * 1.2)

		local fadeAlpha = if lifeAlpha > 0.82 then (lifeAlpha - 0.82) / 0.18 else 0
		part.Transparency = math.clamp(0.08 + fadeAlpha * 0.92, 0.08, 1)
	end
end

local function collectTargetsInRadius(
	center: Vector3,
	radius: number,
	targetGroup: TargetGroup,
	caster: Entity,
	includeCaster: boolean
): { Entity }
	if targetGroup == "Enemies" then
		return EnemyServiceServer.GetInRadius(center, radius)
	end

	local results = {}
	local radiusSq = radius * radius
	for _, entity in pairs(PlayerServiceServer.GetPlayers()) do
		if entity:IsAlive() then
			if not includeCaster and entity == caster then
				continue
			end

			local offset = entity.RootPart.Position - center
			local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
			if distanceSq <= radiusSq then
				table.insert(results, entity)
			end
		end
	end

	return results
end

local function ensureSpellAttachment(rootPart: BasePart): Attachment
	local attachment = rootPart:FindFirstChild("RootAttachment")
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	local created = Instance.new("Attachment")
	created.Name = "RootAttachment"
	created.Parent = rootPart
	return created
end

local function ensureSpellLinearVelocity(rootPart: BasePart): LinearVelocity
	local existing = rootPart:FindFirstChild(SPELL_LINEAR_VELOCITY_NAME)
	if existing and existing:IsA("LinearVelocity") then
		return existing
	end

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = SPELL_LINEAR_VELOCITY_NAME
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.MaxForce = 999999
	linearVelocity.Parent = rootPart
	return linearVelocity
end

local function setSpellVelocity(target: Entity, velocity: Vector3)
	local rootPart = target.RootPart
	if not rootPart or rootPart.Parent == nil then
		return
	end

	local linearVelocity = ensureSpellLinearVelocity(rootPart)
	linearVelocity.Attachment0 = ensureSpellAttachment(rootPart)
	linearVelocity.VectorVelocity = velocity
	linearVelocity.Enabled = true
	EntitiesWithSpellVelocity[target] = true
end

local function clearSpellVelocity(target: Entity)
	local rootPart = target.RootPart
	if rootPart and rootPart.Parent then
		local linearVelocity = rootPart:FindFirstChild(SPELL_LINEAR_VELOCITY_NAME)
		if linearVelocity then
			linearVelocity:Destroy()
		end
	end

	EntitiesWithSpellVelocity[target] = nil
end

local function destroyTornadoZone(zone: TornadoZone)
	for _, target in pairs(zone.AffectedTargets) do
		if target and target:IsAlive() then
			target:RemoveModifiersFromSource(zone.Source)
		end
	end

	for _, part in ipairs(zone.VisualParts) do
		if part and part.Parent then
			Debris:AddItem(part, 0.2)
		end
	end
end

function SpellServiceServer.ApplyTemporaryModifiers(target: Entity, source: string, modifiers: { ItemModifier })
	applyTemporaryModifiers(target, source, modifiers)
end

function SpellServiceServer.CreateTornado(caster: Entity, options: TornadoOptions): boolean
	if not caster or not caster:IsAlive() then
		print("[SpellServiceServer] Tornado creation skipped: caster missing or dead")
		return false
	end

	local radius = math.max(0.1, options.Range or options.Radius or DEFAULT_TORNADO_RADIUS)
	local duration = math.max(0.05, options.Duration or DEFAULT_TORNADO_DURATION)
	local tickRate = math.max(0.05, options.TickRate or DEFAULT_TORNADO_TICK_RATE)
	local damagePerTick = math.max(0, options.DamagePerTick or 0)
	local modifiers = options.Modifiers or {}
	local pullSpeed = math.max(0, options.PullSpeed or DEFAULT_TORNADO_PULL_SPEED)
	local minPullSpeed = math.max(0, options.MinPullSpeed or DEFAULT_TORNADO_MIN_PULL_SPEED)
	local hasTickEffect = damagePerTick > 0 or #modifiers > 0 or options.OnTickTarget ~= nil
	local hasPullEffect = pullSpeed > 0 or minPullSpeed > 0
	if not hasTickEffect and not hasPullEffect then
		print("[SpellServiceServer] Tornado creation skipped: no pull or tick effect configured")
		return false
	end

	local startAt = now()
	local zone: TornadoZone = {
		Id = HttpService:GenerateGUID(false),
		Caster = caster,
		Center = options.Center,
		PullTarget = options.Center + Vector3.new(0, options.PullHeight or DEFAULT_TORNADO_PULL_HEIGHT, 0),
		Radius = radius,
		Source = options.Source or string.format("spell:tornado:%s:%s", caster.UUID, HttpService:GenerateGUID(false)),
		TargetGroup = options.TargetGroup or "Enemies",
		IncludeCaster = options.IncludeCaster == true,
		EndsAt = startAt + duration,
		NextTickAt = startAt,
		TickRate = tickRate,
		DamagePerTick = damagePerTick,
		Modifiers = modifiers,
		ContactDuration = math.max(0.05, options.ContactModifierDuration or DEFAULT_TORNADO_CONTACT_DURATION),
		PullSpeed = pullSpeed,
		MinPullSpeed = minPullSpeed,
		MaxResultantSpeed = math.max(0, options.MaxResultantSpeed or DEFAULT_TORNADO_MAX_RESULTANT_SPEED),
		LiftVelocity = options.LiftVelocity or DEFAULT_TORNADO_LIFT_VELOCITY,
		DeadzoneRadius = math.max(0, options.DeadzoneRadius or DEFAULT_TORNADO_DEADZONE_RADIUS),
		AffectedTargets = {},
		ContactExpiresAt = {},
		OnTickTarget = options.OnTickTarget,
		VisualParts = {},
		VisualStartedAt = startAt,
	}
	zone.VisualParts = createTornadoVisual(zone)
	table.insert(ActiveTornadoZones, zone)
	print(
		string.format(
			"[SpellServiceServer] Tornado created caster=%s center=(%.2f, %.2f, %.2f) pullTarget=(%.2f, %.2f, %.2f) duration=%.2f range=%.2f strength=%.2f targetGroup=%s",
			caster.Name,
			zone.Center.X,
			zone.Center.Y,
			zone.Center.Z,
			zone.PullTarget.X,
			zone.PullTarget.Y,
			zone.PullTarget.Z,
			duration,
			radius,
			zone.PullSpeed,
			zone.TargetGroup
		)
	)

	return true
end

local function stepTornadoZones(currentTime: number)
	local desiredVelocities: { [Entity]: Vector3 } = {}
	local activeVelocityTargets: { [Entity]: true } = {}

	for index = #ActiveTornadoZones, 1, -1 do
		local zone = ActiveTornadoZones[index]
		if currentTime >= zone.EndsAt or not zone.Caster:IsAlive() then
			destroyTornadoZone(zone)
			table.remove(ActiveTornadoZones, index)
			continue
		end

		local refreshExpiresAt: { [string]: number } = {}
		for _, target in ipairs(collectTargetsInRadius(zone.Center, zone.Radius, zone.TargetGroup, zone.Caster, zone.IncludeCaster)) do
			if target:IsAlive() then
				local pullDelta = zone.PullTarget - target.RootPart.Position
				local flatDistance = Vector3.new(pullDelta.X, 0, pullDelta.Z).Magnitude

				if flatDistance > zone.DeadzoneRadius and pullDelta.Magnitude > 0.001 then
					local distanceAlpha = math.clamp(flatDistance / zone.Radius, 0, 1)
					local pullSpeed = math.max(zone.MinPullSpeed, zone.PullSpeed * distanceAlpha)
					local velocity = pullDelta.Unit * pullSpeed + Vector3.new(0, zone.LiftVelocity, 0)
					local currentVelocity = desiredVelocities[target] or Vector3.zero
					local nextVelocity = currentVelocity + velocity
					if nextVelocity.Magnitude > zone.MaxResultantSpeed then
						nextVelocity = nextVelocity.Unit * zone.MaxResultantSpeed
					end
					desiredVelocities[target] = nextVelocity
					activeVelocityTargets[target] = true
				end

				if currentTime >= zone.NextTickAt then
					if zone.DamagePerTick > 0 then
						Damage.TrueDamage(zone.Caster, target, zone.DamagePerTick)
					end

					if #zone.Modifiers > 0 then
						if zone.AffectedTargets[target.UUID] == nil then
							zone.AffectedTargets[target.UUID] = target
							applyTemporaryModifiers(target, zone.Source, zone.Modifiers)
						end
						refreshExpiresAt[target.UUID] = currentTime + zone.ContactDuration
					end

					if zone.OnTickTarget then
						zone.OnTickTarget(zone.Caster, target, zone)
					end
				end
			end
		end

		if currentTime >= zone.NextTickAt then
			zone.NextTickAt = currentTime + zone.TickRate
			for targetUUID, expireAt in pairs(refreshExpiresAt) do
				zone.ContactExpiresAt[targetUUID] = expireAt
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

		updateTornadoVisual(zone, currentTime)
	end

	for target in pairs(activeVelocityTargets) do
		local velocity = desiredVelocities[target]
		if velocity and target:IsAlive() then
			setSpellVelocity(target, velocity)
		end
	end

	for target in pairs(EntitiesWithSpellVelocity) do
		if not activeVelocityTargets[target] or not target:IsAlive() then
			clearSpellVelocity(target)
		end
	end
end

RunService.Heartbeat:Connect(function()
	stepTornadoZones(now())
end)

return table.freeze(SpellServiceServer)
