--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local API = script.Parent:WaitForChild("AttackEndpoint") :: RemoteEvent

local AttackServiceClient = {}
local LocalPlayer = Players.LocalPlayer
local EntitiesFolder = workspace:WaitForChild("EntitiesFolder")

type ActiveAttack = {
	AttackId: string,
	HitWindows: {
		{
			Index: number,
			ActiveFrom: number,
			ActiveUntil: number,
		},
	},
	ClearAt: number,
	Profile: {
		HitReset: number,
		HitboxSize: Vector3,
		HitboxOffset: CFrame,
	},
	LastReportedAt: { [number]: { [string]: number } },
}

local ActiveAttackState: ActiveAttack? = nil
local HitboxVisualizer: Part? = nil

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = { EntitiesFolder }
overlapParams.MaxParts = 32

local function GetHitboxCFrame(rootPart: BasePart, attack: ActiveAttack): CFrame
	return rootPart.CFrame * attack.Profile.HitboxOffset
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

local function UpdateHitboxVisualizer(attack: ActiveAttack)
	local character = LocalPlayer.Character
	if not character or not character.PrimaryPart then
		return
	end

	local hitbox = EnsureHitboxVisualizer()
	hitbox.Size = attack.Profile.HitboxSize
	hitbox.CFrame = GetHitboxCFrame(character.PrimaryPart, attack)
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
	local parts = workspace:GetPartBoundsInBox(GetHitboxCFrame(character.PrimaryPart, attack), attack.Profile.HitboxSize, overlapParams)
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
		if lastReported and now - lastReported < attack.Profile.HitReset then
			continue
		end

		lastReportedAt[targetUUID] = now
		API:FireServer("ReportHit", {
			AttackId = attack.AttackId,
			TargetUUID = targetUUID,
			HitWindowIndex = activeHitWindow.Index,
		})
	end
end

function AttackServiceClient.PrimaryAttack(): ()
	API:FireServer("RequestPrimaryAttack", {})
end

function AttackServiceClient.BeginBowCharge(): ()
	API:FireServer("BeginBowCharge", {})
end

function AttackServiceClient.ReleaseBowCharge(payload: { [string]: any }?): ()
	API:FireServer("ReleaseBowCharge", payload or {})
end

API.OnClientEvent:Connect(function(action: string, payload: { [string]: any })
	if action ~= "AttackStarted" then
		return
	end

	ActiveAttackState = {
		AttackId = payload.AttackId,
		HitWindows = payload.HitWindows,
		ClearAt = payload.ClearAt,
		Profile = payload.Profile,
		LastReportedAt = {},
	}
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

	local isAnyHitWindowActive = false
	for _, hitWindow in ipairs(attack.HitWindows) do
		if now >= hitWindow.ActiveFrom and now <= hitWindow.ActiveUntil then
			isAnyHitWindowActive = true
			break
		end
	end

	if not isAnyHitWindowActive then
		HideHitboxVisualizer()
		return
	end

	UpdateHitboxVisualizer(attack)
	ReportOverlapHits(attack)
end)

return table.freeze(AttackServiceClient)
