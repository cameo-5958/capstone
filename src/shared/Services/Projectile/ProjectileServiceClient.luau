--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local API = script.Parent:WaitForChild("ProjectileEndpoint") :: RemoteEvent

local ProjectileServiceClient = {}

local ActiveVisuals: { [number]: {
	Position: Vector3,
	Velocity: Vector3,
	GravityScale: number,
	DistanceTravelled: number,
	MaxDistance: number,
	Visual: BasePart,
} } = {}

local function DestroyProjectile(projectileId: number)
	local projectile = ActiveVisuals[projectileId]
	if not projectile then
		return
	end

	projectile.Visual:Destroy()
	ActiveVisuals[projectileId] = nil
end

local function UpdateVisual(projectile)
	local velocity = projectile.Velocity
	local direction = if velocity.Magnitude > 0.001 then velocity.Unit else Vector3.zAxis
	projectile.Visual.CFrame = CFrame.lookAt(projectile.Position, projectile.Position + direction)
end

local function SpawnProjectile(payload)
	local sourceArrow = payload.SourceArrow
	if not sourceArrow or not sourceArrow:IsA("BasePart") then
		return
	end

	DestroyProjectile(payload.ProjectileId)

	local clone = sourceArrow:Clone()
	clone.Name = "ProjectileArrow"
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Parent = workspace

	ActiveVisuals[payload.ProjectileId] = {
		Position = payload.Position,
		Velocity = payload.Velocity,
		GravityScale = payload.GravityScale,
		DistanceTravelled = 0,
		MaxDistance = payload.MaxDistance,
		Visual = clone,
	}
	UpdateVisual(ActiveVisuals[payload.ProjectileId])
end

API.OnClientEvent:Connect(function(action: string, payload)
	if action == "SpawnProjectile" then
		SpawnProjectile(payload)
	elseif action == "DestroyProjectile" and payload then
		DestroyProjectile(payload.ProjectileId)
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	for projectileId, projectile in pairs(ActiveVisuals) do
		local gravity = Vector3.new(0, -workspace.Gravity * projectile.GravityScale, 0)
		local nextVelocity = projectile.Velocity + gravity * dt
		local nextPosition = projectile.Position + projectile.Velocity * dt + (gravity * (0.5 * dt * dt))
		projectile.DistanceTravelled += (nextPosition - projectile.Position).Magnitude
		projectile.Position = nextPosition
		projectile.Velocity = nextVelocity
		UpdateVisual(projectile)

		if projectile.DistanceTravelled >= projectile.MaxDistance then
			DestroyProjectile(projectileId)
		end
	end
end)

return table.freeze(ProjectileServiceClient)
