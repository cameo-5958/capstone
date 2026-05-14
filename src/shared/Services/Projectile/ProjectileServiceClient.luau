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
	Speed: number,
	GravityScale: number,
	HomingStrength: number,
	DistanceTravelled: number,
	MaxDistance: number,
	TargetRootPart: BasePart?,
	Visual: BasePart,
} } = {}

local function createFallbackArrowVisual(): BasePart
	local part = Instance.new("Part")
	part.Name = "ProjectileArrowFallback"
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Material = Enum.Material.Wood
	part.Color = Color3.fromRGB(111, 78, 55)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local frontAttachment = Instance.new("Attachment")
	frontAttachment.Name = "TrailFront"
	frontAttachment.Position = Vector3.new(0, 0, -0.2)
	frontAttachment.Parent = part

	local backAttachment = Instance.new("Attachment")
	backAttachment.Name = "TrailBack"
	backAttachment.Position = Vector3.new(0, 0, 0.2)
	backAttachment.Parent = part

	local trail = Instance.new("Trail")
	trail.Name = "ProjectileTrail"
	trail.Attachment0 = frontAttachment
	trail.Attachment1 = backAttachment
	trail.Color = ColorSequence.new(Color3.fromRGB(181, 130, 84), Color3.fromRGB(96, 67, 44))
	trail.LightEmission = 0.15
	trail.Lifetime = 0.12
	trail.MinLength = 0
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	trail.Parent = part

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

	DestroyProjectile(payload.ProjectileId)

	local clone = createFallbackArrowVisual()
	clone.Name = "ProjectileArrow"
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Parent = workspace

	ActiveVisuals[payload.ProjectileId] = {
		Position = payload.Position,
		Velocity = payload.Velocity,
		Speed = if typeof(payload.Speed) == "number" then payload.Speed else payload.Velocity.Magnitude,
		GravityScale = if typeof(payload.GravityScale) == "number" then payload.GravityScale else 1,
		HomingStrength = if typeof(payload.HomingStrength) == "number" then payload.HomingStrength else 0,
		DistanceTravelled = 0,
		MaxDistance = if typeof(payload.MaxDistance) == "number" then payload.MaxDistance else 80,
		TargetRootPart = if payload.TargetRootPart and payload.TargetRootPart:IsA("BasePart") then payload.TargetRootPart else nil,
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
		local targetRootPart = projectile.TargetRootPart
		local hasTarget = targetRootPart ~= nil and targetRootPart.Parent ~= nil
		local nextVelocity = projectile.Velocity
		if hasTarget then
			local desiredDirection = targetRootPart.Position + Vector3.new(0, 1.5, 0) - projectile.Position
			if desiredDirection.Magnitude > 0.001 and projectile.Speed > 0.001 then
				local desiredVelocity = desiredDirection.Unit * projectile.Speed
				local blendAlpha = math.clamp(projectile.HomingStrength * dt, 0, 1)
				nextVelocity = projectile.Velocity:Lerp(desiredVelocity, blendAlpha)
				if nextVelocity.Magnitude > 0.001 then
					nextVelocity = nextVelocity.Unit * projectile.Speed
				end
			end
		end

		local gravityScale = if hasTarget then 0 else projectile.GravityScale
		local gravity = Vector3.new(0, -workspace.Gravity * gravityScale, 0)
		nextVelocity += gravity * dt
		local nextPosition = projectile.Position + nextVelocity * dt
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
