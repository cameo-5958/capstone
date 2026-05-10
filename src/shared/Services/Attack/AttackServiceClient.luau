--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AttackServiceClient = {}
local LocalPlayer = Players.LocalPlayer
local EntitiesFolder = workspace:WaitForChild("EntitiesFolder")
local API: RemoteEvent? = nil
local APIConnection: RBXScriptConnection? = nil
local warnedEndpointMissing = false

type ActiveAttack = {
	AttackId: string,
	HitWindows: {
		{
			Index: number,
			ActiveFrom: number,
			ActiveUntil: number,
			Profile: {
				HitReset: number,
				HitboxSize: Vector3,
				HitboxOffset: CFrame,
			},
		}
	},
	ClearAt: number,
	LastReportedAt: { [number]: { [string]: number } },
}

local ActiveAttackState: ActiveAttack? = nil
local HitboxVisualizer: Part? = nil

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = { EntitiesFolder }
overlapParams.MaxParts = 32

local function fireServer(action: string, payload: { [string]: any }?)
	local remote = API
	if not remote then
		if not warnedEndpointMissing then
			warn("[AttackServiceClient] AttackEndpoint is not ready yet; attack inputs are being dropped until it appears.")
			warnedEndpointMissing = true
		end
		return
	end

	remote:FireServer(action, payload or {})
end

local function GetHitboxCFrame(rootPart: BasePart, hitWindow): CFrame
	return rootPart.CFrame * hitWindow.Profile.HitboxOffset
end

local function EnsureHitboxVisualizer(): Part
	local hitbox = HitboxVisualizer
	if hitbox and hitbox.Parent then
		return hitbox
	end

	hitbox = Instance.new("Part")
	hitbox.Name = "AttackHitboxVisualizer"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CanTouch = false
	hitbox.Material = Enum.Material.ForceField
	hitbox.Color = Color3.fromRGB(255, 180, 120)
	hitbox.Transparency = 0.75
	hitbox.Parent = workspace
	HitboxVisualizer = hitbox

	return hitbox
end

local function UpdateHitboxVisualizer(attack: ActiveAttack, hitWindow)
	local character = LocalPlayer.Character
	if not character or not character.PrimaryPart then
		return
	end

	local hitbox = EnsureHitboxVisualizer()
	hitbox.Size = hitWindow.Profile.HitboxSize
	hitbox.CFrame = GetHitboxCFrame(character.PrimaryPart, hitWindow)
end

local function HideHitboxVisualizer()
	if HitboxVisualizer then
		HitboxVisualizer:Destroy()
		HitboxVisualizer = nil
	end
end

local function ReportOverlapHits(attack: ActiveAttack)
	local character = LocalPlayer.Character
	if not character or not character.PrimaryPart then
		return
	end

	local now = workspace:GetServerTimeNow()
	local activeHitWindow = nil
	for _, hitWindow in ipairs(attack.HitWindows) do
		if now >= hitWindow.ActiveFrom and now <= hitWindow.ActiveUntil then
			activeHitWindow = hitWindow
			break
		end
	end

	if not activeHitWindow then
		return
	end

	attack.LastReportedAt[activeHitWindow.Index] = attack.LastReportedAt[activeHitWindow.Index] or {}
	local lastReportedAt = attack.LastReportedAt[activeHitWindow.Index]
	local parts = workspace:GetPartBoundsInBox(
		GetHitboxCFrame(character.PrimaryPart, activeHitWindow),
		activeHitWindow.Profile.HitboxSize,
		overlapParams
	)
	local seenThisFrame = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if not model or not model:IsDescendantOf(EntitiesFolder) then
			continue
		end

		local targetUUID = model.Name
		if seenThisFrame[targetUUID] then
			continue
		end

		seenThisFrame[targetUUID] = true

		local lastReported = lastReportedAt[targetUUID]
		if lastReported and now - lastReported < activeHitWindow.Profile.HitReset then
			continue
		end

		lastReportedAt[targetUUID] = now
		fireServer("ReportHit", {
			AttackId = attack.AttackId,
			TargetUUID = targetUUID,
			HitWindowIndex = activeHitWindow.Index,
		})
	end
end

function AttackServiceClient.PrimaryAttack(): ()
	fireServer("RequestPrimaryAttack", {})
end

function AttackServiceClient.BeginBowCharge(): ()
	fireServer("BeginBowCharge", {})
end

function AttackServiceClient.ReleaseBowCharge(payload: { [string]: any }?): ()
	fireServer("ReleaseBowCharge", payload or {})
end

local function onClientEvent(action: string, payload: { [string]: any })
	if action ~= "AttackStarted" then
		return
	end

	ActiveAttackState = {
		AttackId = payload.AttackId,
		HitWindows = payload.HitWindows,
		ClearAt = payload.ClearAt,
		LastReportedAt = {},
	}
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

local existingEndpoint = script.Parent:FindFirstChild("AttackEndpoint")
if existingEndpoint then
	bindAPI(existingEndpoint)
end

script.Parent.ChildAdded:Connect(function(child)
	if child.Name == "AttackEndpoint" then
		bindAPI(child)
	end
end)

RunService.Heartbeat:Connect(function()
	local attack = ActiveAttackState
	if not attack then
		return
	end

	local now = workspace:GetServerTimeNow()
	if now > attack.ClearAt then
		ActiveAttackState = nil
		HideHitboxVisualizer()
		return
	end

	local activeHitWindow = nil
	for _, hitWindow in ipairs(attack.HitWindows) do
		if now >= hitWindow.ActiveFrom and now <= hitWindow.ActiveUntil then
			activeHitWindow = hitWindow
			break
		end
	end

	if not activeHitWindow then
		HideHitboxVisualizer()
		return
	end

	UpdateHitboxVisualizer(attack, activeHitWindow)
	ReportOverlapHits(attack)
end)

return table.freeze(AttackServiceClient)
