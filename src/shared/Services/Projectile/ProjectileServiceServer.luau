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
	MaxDistance: number,
	GravityScale: number,
	Radius: number,
	DamageScale: number,
	Owner: Entity,
	Weapon: Weapon,
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

local function GetArrowSourcePart(weapon: Weapon): BasePart?
	local tool = weapon.ToolInstance or weapon.ToolTemplate
	if not tool then
		return nil
	end

	local arrow = tool:FindFirstChild("Arrow", true)
	if arrow and arrow:IsA("BasePart") then
		return arrow
	end

	return nil
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

local function StepProjectile(projectileId: number, projectile: ActiveProjectile, dt: number)
	local gravity = Vector3.new(0, -workspace.Gravity * projectile.GravityScale, 0)
	local startPosition = projectile.Position
	local nextVelocity = projectile.Velocity + gravity * dt
	local nextPosition = projectile.Position + projectile.Velocity * dt + (gravity * (0.5 * dt * dt))
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
	local spawnPosition = definition.Position
	local sourceArrow = GetArrowSourcePart(definition.Weapon)
	if sourceArrow then
		spawnPosition = sourceArrow.Position
	end

	NextProjectileId += 1
	ActiveProjectiles[NextProjectileId] = {
		Position = spawnPosition,
		Velocity = definition.Velocity,
		MaxDistance = definition.MaxDistance,
		GravityScale = definition.GravityScale,
		Radius = definition.Radius,
		DamageScale = definition.DamageScale,
		Owner = definition.Owner,
		Weapon = definition.Weapon,
		DistanceTravelled = 0,
		ProjectileId = NextProjectileId,
	}

	API:FireAllClients("SpawnProjectile", {
		ProjectileId = NextProjectileId,
		Position = spawnPosition,
		Velocity = definition.Velocity,
		GravityScale = definition.GravityScale,
		MaxDistance = definition.MaxDistance,
		SourceArrow = sourceArrow,
	})

	return NextProjectileId
end

RunService.Heartbeat:Connect(function(dt: number)
	for projectileId, projectile in pairs(ActiveProjectiles) do
		StepProjectile(projectileId, projectile, dt)
	end
end)

return table.freeze(ProjectileServiceServer)
