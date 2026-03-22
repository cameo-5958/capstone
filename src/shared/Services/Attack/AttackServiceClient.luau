--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local API = script.Parent:WaitForChild("AttackEndpoint") :: RemoteEvent

local AttackServiceClient = {}
local LocalPlayer = Players.LocalPlayer
local EntitiesFolder = workspace:WaitForChild("EntitiesFolder")

type ActiveAttack = {
	AttackId: string,
	ActiveFrom: number,
	ActiveUntil: number,
	ClearAt: number,
	Profile: {
		HitReset: number,
		HitboxSize: Vector3,
		HitboxOffset: CFrame,
	},
	LastReportedAt: { [string]: number },
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

		local lastReported = attack.LastReportedAt[targetUUID]
		if lastReported and now - lastReported < attack.Profile.HitReset then
			continue
		end

		attack.LastReportedAt[targetUUID] = now
		API:FireServer("ReportHit", {
			AttackId = attack.AttackId,
			TargetUUID = targetUUID,
		})
	end
end

function AttackServiceClient.PrimaryAttack(): ()
	API:FireServer("RequestPrimaryAttack", {})
end

API.OnClientEvent:Connect(function(action: string, payload: { [string]: any })
	if action ~= "AttackStarted" then
		return
	end

	ActiveAttackState = {
		AttackId = payload.AttackId,
		ActiveFrom = payload.ActiveFrom,
		ActiveUntil = payload.ActiveUntil,
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

	if now < attack.ActiveFrom or now > attack.ActiveUntil then
		HideHitboxVisualizer()
		return
	end

	UpdateHitboxVisualizer(attack)
	ReportOverlapHits(attack)
end)

return table.freeze(AttackServiceClient)
