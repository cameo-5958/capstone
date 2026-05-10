--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProjectileServiceClient = {}
local API: RemoteEvent? = nil
local APIConnection: RBXScriptConnection? = nil
local warnedEndpointMissing = false

local ActiveVisuals: { [number]: {
	Position: Vector3,
	Velocity: Vector3,
	GravityScale: number,
	DistanceTravelled: number,
	MaxDistance: number,
	Visual: BasePart,
} } = {}

local function createFallbackArrowVisual(): BasePart
	local part = Instance.new("Part")
	part.Name = "ProjectileArrowFallback"
	part.Size = Vector3.new(0.25, 0.25, 2.2)
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(184, 184, 194)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

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
	if type(payload) ~= "table" then
		return
	end

	if typeof(payload.ProjectileId) ~= "number" then
		return
	end

	if typeof(payload.Position) ~= "Vector3" or typeof(payload.Velocity) ~= "Vector3" then
		return
	end

	local sourceArrow = payload.SourceArrow

	DestroyProjectile(payload.ProjectileId)

	local clone: BasePart
	if sourceArrow and sourceArrow:IsA("BasePart") then
		clone = sourceArrow:Clone() :: BasePart
	else
		clone = createFallbackArrowVisual()
	end
	clone.Name = "ProjectileArrow"
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Parent = workspace

	ActiveVisuals[payload.ProjectileId] = {
		Position = payload.Position,
		Velocity = payload.Velocity,
		GravityScale = if typeof(payload.GravityScale) == "number" then payload.GravityScale else 1,
		DistanceTravelled = 0,
		MaxDistance = if typeof(payload.MaxDistance) == "number" then payload.MaxDistance else 80,
		Visual = clone,
	}
	UpdateVisual(ActiveVisuals[payload.ProjectileId])
end

local function onClientEvent(action: string, payload)
	if action == "SpawnProjectile" then
		SpawnProjectile(payload)
	elseif action == "DestroyProjectile" and payload then
		DestroyProjectile(payload.ProjectileId)
	end
end

local function bindAPI(candidate: Instance)
	if not candidate:IsA("RemoteEvent") then
		return
	end

	local remote = candidate :: RemoteEvent
	if API == remote then
		return
	end

	API = remote
	warnedEndpointMissing = false
	if APIConnection then
		APIConnection:Disconnect()
		APIConnection = nil
	end
	APIConnection = remote.OnClientEvent:Connect(onClientEvent)
end

local existingEndpoint = script.Parent:FindFirstChild("ProjectileEndpoint")
if existingEndpoint then
	bindAPI(existingEndpoint)
elseif not warnedEndpointMissing then
	warn("[ProjectileServiceClient] ProjectileEndpoint is not ready yet; waiting for endpoint.")
	warnedEndpointMissing = true
end

script.Parent.ChildAdded:Connect(function(child)
	if child.Name == "ProjectileEndpoint" then
		bindAPI(child)
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
