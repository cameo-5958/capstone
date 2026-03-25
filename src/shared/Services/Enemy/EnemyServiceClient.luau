--!strict
-- Mostly an utility module

-- Grab API endpoints
local API: RemoteEvent = script.Parent:WaitForChild("EnemyEndpoint")
local Handler: RemoteEvent = script.Parent:WaitForChild("EnemyHandler")

-- Require
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Entity = require(ReplicatedStorage.Classes.Entity.Entity)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)
type Entity = EntityTypes.Entity

local __Enemies: {
	[string]: Entity,
} = {}
local __LookTargets: {
	[string]: Vector3?,
} = {}
local __VelocityCancelTasks: {
	[string]: thread?,
} = {}
local __AttackHitboxes: {
	[string]: {
		Part: Part,
		ActiveFrom: number,
		ActiveUntil: number,
		ClearAt: number,
		HitboxSize: Vector3,
		HitboxOffset: CFrame,
	},
} = {}
local LOCAL_LINEAR_VELOCITY_NAME = "ClientLinearVelocity"

local function ClearAttackHitbox(uuid: string)
	local state = __AttackHitboxes[uuid]
	if not state then
		return
	end

	state.Part:Destroy()
	__AttackHitboxes[uuid] = nil
end

local function EnsureAttackHitbox(uuid: string): Part
	local existing = __AttackHitboxes[uuid]
	if existing and existing.Part.Parent then
		return existing.Part
	end

	local part = Instance.new("Part")
	part.Name = "EnemyAttackHitboxVisualizer"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(255, 90, 90)
	part.Transparency = 0.82
	part.Parent = workspace

	return part
end

local function CancelLinearVelocityVisual(uuid: string)
	local pending = __VelocityCancelTasks[uuid]
	if pending then
		task.cancel(pending)
		__VelocityCancelTasks[uuid] = nil
	end

	local ent = __Enemies[uuid]
	if not ent or not ent.Character or not ent.Character.PrimaryPart then
		return
	end

	local lv = ent.Character:FindFirstChild("LinearVelocity")
		or ent.Character:FindFirstChild(LOCAL_LINEAR_VELOCITY_NAME)
	if lv then
		lv:Destroy()
	end

	(ent.Character.PrimaryPart :: BasePart).AssemblyLinearVelocity = Vector3.zero
end

local function ApplyLinearVelocityVisual(uuid: string, velocity: Vector3, duration: number)
	local ent = __Enemies[uuid]
	if not ent or not ent.Character or not ent.Character.PrimaryPart then
		return
	end

	CancelLinearVelocityVisual(uuid)

	local rootPart = ent.Character.PrimaryPart :: BasePart
	local attachment = rootPart:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		return
	end

	local lv = Instance.new("LinearVelocity")
	lv.Name = LOCAL_LINEAR_VELOCITY_NAME
	lv.Attachment0 = attachment
	lv.VectorVelocity = velocity
	lv.MaxForce = 999999
	lv.Parent = ent.Character
	rootPart.AssemblyLinearVelocity = Vector3.zero

	__VelocityCancelTasks[uuid] = task.delay(duration, function()
		__VelocityCancelTasks[uuid] = nil
		CancelLinearVelocityVisual(uuid)
	end)
end

-- Public API
local Enemies = {}

-- API Handshakes
API.OnClientEvent:Connect(function(ds: { [string]: { [string]: Entity } })
	-- Delay the task to ensure that the models are all
	-- loaded in
	task.delay(0.5, function()
		-- Create
		for uuid, ent in pairs(ds["Create"]) do
			-- Cast to Entity to give functionality back
			__Enemies[uuid] = Entity.Inflate(ent)
		end
	end)
end)

-- Find closest
function Enemies.GetClosest(pos: Vector3, sight: number?)
	local closest = ""
	local closestDistance = sight or 64

	for uuid, ent in pairs(__Enemies) do
		-- Find the distance between pos and
		-- ent location
		local dist = (ent.RootPart.Position - pos).Magnitude

		if dist < closestDistance then
			closestDistance = dist
			closest = uuid
		end
	end

	return __Enemies[closest]
end

function Enemies.GetAll()
	return __Enemies
end

-- Handle movement etc.
Handler.OnClientEvent:Connect(function(action: string, data: { [string]: any })
	if action == "Move" then
		local ent = __Enemies[data.UUID]
		if ent and ent.Character and ent.Character:FindFirstChild("Humanoid") then
			(ent.Character:FindFirstChild("Humanoid") :: Humanoid):MoveTo(data.Position)
		end
		CancelLinearVelocityVisual(data.UUID)

		__LookTargets[data.UUID] = data.LookAt
	elseif action == "Pivot" then
		local ent = __Enemies[data.UUID]
		if ent and ent.Character and ent.Character.PrimaryPart then
			ent.Character.PrimaryPart:PivotTo(data.CFrame)
		end
		CancelLinearVelocityVisual(data.UUID)
		__LookTargets[data.UUID] = nil
	elseif action == "Face" then
		__LookTargets[data.UUID] = data.LookAt
	elseif action == "LinearVelocity" then
		ApplyLinearVelocityVisual(data.UUID, data.Velocity, data.Duration)
	elseif action == "CancelLinearVelocity" then
		CancelLinearVelocityVisual(data.UUID)
	elseif action == "AttackHitbox" then
		local hitbox = EnsureAttackHitbox(data.UUID)
		__AttackHitboxes[data.UUID] = {
			Part = hitbox,
			ActiveFrom = data.ActiveFrom,
			ActiveUntil = data.ActiveUntil,
			ClearAt = data.ClearAt,
			HitboxSize = data.HitboxSize,
			HitboxOffset = data.HitboxOffset,
		}
	end
end)

RunService.Heartbeat:Connect(function()
	for uuid, target in pairs(__LookTargets) do
		local ent = __Enemies[uuid]
		if not target or not ent or not ent.Character or not ent.Character.PrimaryPart then
			continue
		end
	end

	local now = workspace:GetServerTimeNow()
	for uuid, state in pairs(__AttackHitboxes) do
		local ent = __Enemies[uuid]
		if now > state.ClearAt or not ent or not ent.Character or not ent.Character.PrimaryPart then
			ClearAttackHitbox(uuid)
			continue
		end

		if now < state.ActiveFrom or now > state.ActiveUntil then
			state.Part.Transparency = 1
			continue
		end

		state.Part.Transparency = 0.82
		state.Part.Size = state.HitboxSize
		state.Part.CFrame = ent.Character.PrimaryPart.CFrame * state.HitboxOffset
	end
end)

return table.freeze(Enemies)
