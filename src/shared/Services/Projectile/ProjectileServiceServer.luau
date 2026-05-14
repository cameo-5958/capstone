--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local endpoint = script.Parent:FindFirstChild("ProjectileEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "ProjectileEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent

local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
local WeaponTypes = require(ReplicatedStorage.Classes.Weapon.WeaponTypes)

type Entity = EntityTypes.Entity
type Weapon = WeaponTypes.Weapon

type ProjectileDefinition = {
	Position: Vector3,
	Velocity: Vector3,
	Speed: number?,
	MaxDistance: number,
	GravityScale: number,
	Radius: number,
	DamageScale: number,
	Owner: Entity,
	Weapon: Weapon,
	Target: Entity?,
	HomingStrength: number?,
}

type ActiveProjectile = ProjectileDefinition & {
	DistanceTravelled: number,
	ProjectileId: number,
}

local ProjectileServiceServer = {}
local ActiveProjectiles: { [number]: ActiveProjectile } = {}
local NextProjectileId = 0

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function GetProjectileSourceInstance(weapon: Weapon): Instance?
	local sourceInstance = weapon.VisualInstance or weapon.VisualTemplate
	if not sourceInstance then
		return nil
	end

	local arrowPosition = sourceInstance:FindFirstChild("ArrowPosition", true)
	if arrowPosition then
		return arrowPosition
	end

	local arrow = sourceInstance:FindFirstChild("Arrow", true)
	if arrow then
		return arrow
	end

	return nil
end

local function ResolveProjectileSpawnPosition(
	defaultPosition: Vector3,
	sourceInstance: Instance?
): Vector3
	if not sourceInstance then
		return defaultPosition
	end

	if sourceInstance:IsA("Attachment") then
		return sourceInstance.WorldPosition
	end

	if sourceInstance:IsA("BasePart") then
		return sourceInstance.Position
	end

	return defaultPosition
end

local function RemoveProjectile(projectileId: number)
	if ActiveProjectiles[projectileId] == nil then
		return
	end

	ActiveProjectiles[projectileId] = nil
	API:FireAllClients("DestroyProjectile", {
		ProjectileId = projectileId,
	})
end

local function ResolveTargetFromHit(owner: Entity, instance: Instance): Entity?
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model or model == owner.Character then
		return nil
	end

	local target = EnemyServiceServer.GetByUUID(model.Name)
	if not target or not target:IsAlive() then
		return nil
	end

	if target:IsInvincible() then
		print(("Hit whiffed on invincible target: %s -> %s"):format(owner.Name, target.Name))
		return nil
	end

	return target
end

local function ResolveTargetAimPosition(projectile: ActiveProjectile): Vector3?
	local target = projectile.Target
	if not target or not target:IsAlive() then
		return nil
	end

	return target.RootPart.Position + Vector3.new(0, 1.5, 0)
end

local function StepProjectile(projectileId: number, projectile: ActiveProjectile, dt: number)
	local speed = projectile.Speed or projectile.Velocity.Magnitude
	local targetAimPosition = ResolveTargetAimPosition(projectile)
	local nextVelocity = projectile.Velocity
	if targetAimPosition then
		local desiredDirection = targetAimPosition - projectile.Position
		if desiredDirection.Magnitude > 0.001 and speed > 0.001 then
			local desiredVelocity = desiredDirection.Unit * speed
			local homingStrength = math.max(0, projectile.HomingStrength or 0)
			local blendAlpha = math.clamp(homingStrength * dt, 0, 1)
			nextVelocity = projectile.Velocity:Lerp(desiredVelocity, blendAlpha)
			if nextVelocity.Magnitude > 0.001 then
				nextVelocity = nextVelocity.Unit * speed
			end
		end
	end

	local gravityScale = if targetAimPosition then 0 else projectile.GravityScale
	local gravity = Vector3.new(0, -workspace.Gravity * gravityScale, 0)
	local startPosition = projectile.Position
	nextVelocity += gravity * dt
	local nextPosition = projectile.Position + nextVelocity * dt
	local segment = nextPosition - startPosition
	local segmentLength = segment.Magnitude

	if segmentLength > 0 then
		raycastParams.FilterDescendantsInstances = { projectile.Owner.Character }
		local result = workspace:Spherecast(startPosition, projectile.Radius, segment, raycastParams)
		if result then
			local target = ResolveTargetFromHit(projectile.Owner, result.Instance)
			if target then
				projectile.Weapon:ExecuteAttack(target, projectile.DamageScale, projectile.Owner)
			end

			RemoveProjectile(projectileId)
			return
		end
	end

	projectile.Position = nextPosition
	projectile.Velocity = nextVelocity
	projectile.DistanceTravelled += segmentLength

	if projectile.DistanceTravelled >= projectile.MaxDistance then
		RemoveProjectile(projectileId)
	end
end

function ProjectileServiceServer.FireArrow(definition: ProjectileDefinition): number
	local sourceInstance = GetProjectileSourceInstance(definition.Weapon)
	local spawnPosition = ResolveProjectileSpawnPosition(definition.Position, sourceInstance)

	NextProjectileId += 1
	ActiveProjectiles[NextProjectileId] = {
		Position = spawnPosition,
		Velocity = definition.Velocity,
		Speed = definition.Speed or definition.Velocity.Magnitude,
		MaxDistance = definition.MaxDistance,
		GravityScale = definition.GravityScale,
		Radius = definition.Radius,
		DamageScale = definition.DamageScale,
		Owner = definition.Owner,
		Weapon = definition.Weapon,
		Target = definition.Target,
		HomingStrength = definition.HomingStrength,
		DistanceTravelled = 0,
		ProjectileId = NextProjectileId,
	}

	API:FireAllClients("SpawnProjectile", {
		ProjectileId = NextProjectileId,
		Position = spawnPosition,
		Velocity = definition.Velocity,
		Speed = definition.Speed or definition.Velocity.Magnitude,
		GravityScale = definition.GravityScale,
		HomingStrength = definition.HomingStrength,
		MaxDistance = definition.MaxDistance,
		TargetRootPart = definition.Target and definition.Target.RootPart or nil,
	})

	return NextProjectileId
end

RunService.Heartbeat:Connect(function(dt: number)
	for projectileId, projectile in pairs(ActiveProjectiles) do
		StepProjectile(projectileId, projectile, dt)
	end
end)

return table.freeze(ProjectileServiceServer)
