--!strict

local endpoint = script.Parent:FindFirstChild("AttackEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "AttackEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationServiceServer = require(ReplicatedStorage.Services.Animation.AnimationServiceServer)
local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local WeaponModule = require(ReplicatedStorage.Classes.Weapon.Weapon)

local AttackServiceServer = {}

type AttackProfile = WeaponModule.AttackProfile
type ActiveAttack = {
	Id: string,
	Profile: AttackProfile,
	Weapon: any,
	ActiveFrom: number,
	ActiveUntil: number,
	ClearAt: number,
	Hits: { [string]: number },
}

local ActiveAttacks: { [Player]: ActiveAttack } = {}
local NextAttackAt: { [Player]: number } = {}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = { workspace:WaitForChild("EntitiesFolder") }
overlapParams.MaxParts = 32

local function ClearAttackLater(player: Player, attackId: string, clearAt: number, animationId: string)
	local delayTime = math.max(0, clearAt - workspace:GetServerTimeNow())
	task.delay(delayTime, function()
		local active = ActiveAttacks[player]
		if not active or active.Id ~= attackId then
			return
		end

		ActiveAttacks[player] = nil

		if animationId ~= "" then
			AnimationServiceServer.StopPlayer(player, animationId)
		end
	end)
end

local function GetHitboxCFrame(entity, profile: AttackProfile): CFrame
	return entity.RootPart.CFrame * profile.HitboxOffset
end

local function IsTargetInsideHitbox(entity, target, profile: AttackProfile): boolean
	local parts = workspace:GetPartBoundsInBox(GetHitboxCFrame(entity, profile), profile.HitboxSize, overlapParams)
	for _, part in ipairs(parts) do
		if part:IsDescendantOf(target.Character) then
			return true
		end
	end

	return false
end

local function BeginPrimaryAttack(player: Player)
	local now = workspace:GetServerTimeNow()
	if now < (NextAttackAt[player] or 0) then
		return
	end

	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity:IsAlive() then
		return
	end

	local weapon = entity:GetEquippedWeapon()
	if not weapon then
		return
	end

	local profile = weapon:GetAttackProfile()
	local animationId = entity.__Animations["Attack"] or profile.AnimationId
	local attackId = HttpService:GenerateGUID(false)
	local activeFrom = now + profile.Windup
	local activeUntil = activeFrom + profile.ActiveDuration
	local clearAt = activeUntil + profile.Recovery

	NextAttackAt[player] = now + profile.Cooldown
	ActiveAttacks[player] = {
		Id = attackId,
		Profile = profile,
		Weapon = weapon,
		ActiveFrom = activeFrom,
		ActiveUntil = activeUntil,
		ClearAt = clearAt,
		Hits = {},
	}

	if animationId ~= "" then
		AnimationServiceServer.PlayPlayer(player, animationId)
	end

	API:FireClient(player, "AttackStarted", {
		AttackId = attackId,
		ActiveFrom = activeFrom,
		ActiveUntil = activeUntil,
		ClearAt = clearAt,
		Profile = profile,
	})

	ClearAttackLater(player, attackId, clearAt, animationId)
end

local function ReportHit(player: Player, payload: { [string]: any }?)
	if not payload then
		return
	end

	local active = ActiveAttacks[player]
	if not active or active.Id ~= payload.AttackId then
		return
	end

	local now = workspace:GetServerTimeNow()
	if now < active.ActiveFrom or now > active.ActiveUntil then
		return
	end

	local entity = PlayerServiceServer.GetEntity(player)
	if not entity or not entity:IsAlive() then
		return
	end

	local target = EnemyServiceServer.GetByUUID(payload.TargetUUID)
	if not target or not target:IsAlive() then
		return
	end

	local lastHitAt = active.Hits[payload.TargetUUID]
	if lastHitAt and now - lastHitAt < active.Profile.HitReset then
		return
	end

	if not IsTargetInsideHitbox(entity, target, active.Profile) then
		return
	end

	print(("Hitbox registered hit: %s -> %s"):format(player.Name, target.Name))
	active.Hits[payload.TargetUUID] = now
	entity:ApplyDamage(active.Weapon:GetDamage(entity), target)
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action == "RequestPrimaryAttack" then
		BeginPrimaryAttack(player)
	elseif action == "ReportHit" then
		ReportHit(player, payload)
	end
end)

return table.freeze(AttackServiceServer)
