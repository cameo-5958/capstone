--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)
local EnemyHandler = ReplicatedStorage.Services.Enemy:WaitForChild("EnemyHandler") :: RemoteEvent

type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local AttackPlayer = {}
AttackPlayer.__index = AttackPlayer
setmetatable(AttackPlayer, SuperNeuron)

local function GetAttackServiceServer()
	return require(ReplicatedStorage.Services.Attack.AttackServiceServer)
end

local function GetDesiredLungeDistance(self: Neuron, distanceToTarget: number): number
	return math.min(
		self.__Attributes["MaxLungeDistance"],
		math.max(0, distanceToTarget - self.__Attributes["AttackSwingRange"])
	)
end

local function GetEnemyHitboxData(self: Neuron): (Vector3, CFrame)
	local attacker = self.Brain.MovementEngine.Entity
	local equippedWeapon = attacker and attacker:GetEquippedWeapon()
	if equippedWeapon then
		local profile = equippedWeapon:GetAttackProfile()
		return profile.HitboxSize, profile.HitboxOffset
	end

	local hitRange = self.__Attributes["AttackSwingRange"] + 1.5
	return Vector3.new(3.25, 4.5, hitRange), CFrame.new(0, 0, -(hitRange * 0.5))
end

local function GetPredictorData(self: Neuron, flatTarget: Vector3, hitboxWidth: number): (Vector3, CFrame)
	local myPos = self.Brain.RootPart.Position
	local startPos = Vector3.new(myPos.X, myPos.Y - (self.Brain.RootPart.Size.Y * 0.5), myPos.Z)
	local delta = flatTarget - Vector3.new(startPos.X, flatTarget.Y, startPos.Z)
	local distance = math.max(delta.Magnitude + (self.__Attributes["PredictorReachPadding"] or 0), 0.5)
	local direction = if delta.Magnitude > 0.001 then delta.Unit else self.Brain.RootPart.CFrame.LookVector
	local midpoint = startPos + direction * (distance * 0.5)
	local size = Vector3.new(math.max(hitboxWidth, 2.4), 0.35, distance)
	local cframe = CFrame.lookAt(midpoint, midpoint + Vector3.new(direction.X, 0, direction.Z))
	return size, cframe
end

local function GetFlatTargetPosition(self: Neuron, target: Model): Vector3?
	local targetPart = target.PrimaryPart
	if not targetPart then
		return nil
	end

	local myPos = self.Brain.RootPart.Position
	return Vector3.new(targetPart.Position.X, myPos.Y, targetPart.Position.Z)
end

local function PlayChargeStrafeAnimation(self: Neuron): string?
	if os.clock() - self.Brain.LastStrafeEndedAt > self.__Attributes["StrafeCarryWindow"] then
		return nil
	end

	local animationKey = self.Brain.LastStrafeAnimationKey
	if type(animationKey) ~= "string" then
		return nil
	end

	if not self.Brain.MovementEngine.__Animations[animationKey] then
		return nil
	end

	self.Brain.MovementEngine:Play(animationKey)
	return animationKey
end

local function StopChargeStrafeAnimation(self: Neuron, animationKey: string?)
	if animationKey and self.Brain.MovementEngine.__Animations[animationKey] then
		self.Brain.MovementEngine:Stop(animationKey)
	end
end

local function CanEnter(self: Neuron): boolean
	local target = self.Brain.Target
	if not target then
		return false
	end

	if os.clock() < self.__Attributes["CooldownUntil"] then
		return false
	end

	if self.Brain.PendingStrafes > 0 then
		return false
	end

	return self.Brain:Delta(target).Magnitude <= self.__Attributes["AttackSwingRange"] + self.__Attributes["MaxLungeDistance"] + self.__Attributes["AttackRangeBuffer"]
end

local function CanExit(self: Neuron): boolean
	return os.clock() >= self.__Attributes["ExitAt"]
end

local function OnEnter(self: Neuron): ()
	local target = self.Brain.Target
	if not target or not target.PrimaryPart then
		self.__Attributes["ExitAt"] = os.clock()
		return
	end

	self.__Attributes["AttackToken"] += 1
	local attackToken = self.__Attributes["AttackToken"]

	local targetPos = target.PrimaryPart.Position
	local attacker = self.Brain.MovementEngine.Entity
	local targetEntity = PlayerServiceServer.GetEntityFromCharacter(target)
	local attackStartAt = workspace:GetServerTimeNow() + self.__Attributes["ChargeDuration"]
	local totalAttackTime = self.__Attributes["ChargeDuration"] + self.__Attributes["AttackDuration"] + self.__Attributes["ApexPause"]

	self.__Attributes["ExitAt"] = os.clock() + totalAttackTime
	self.__Attributes["CooldownUntil"] = os.clock() + self.__Attributes["Cooldown"]
	self.Brain.RetreatTarget = target
	self.Brain.RetreatUntil = os.clock() + totalAttackTime + self.__Attributes["RetreatDuration"]

	local myPos = self.Brain.RootPart.Position
	local flatTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
	local delta = flatTarget - myPos
	local distanceToTarget = delta.Magnitude
	local attackDirection = distanceToTarget > 0.001 and delta.Unit or self.Brain.RootPart.CFrame.LookVector
	local lungeDistance = GetDesiredLungeDistance(self, distanceToTarget)
	local lungeVelocity = lungeDistance / self.__Attributes["AttackDuration"]

	self.Brain.MovementEngine.Humanoid:MoveTo(myPos)
	self.Brain.MovementEngine:CancelLinearVelocity()
	self.Brain.MovementEngine:DisableMovement()
	self.Brain.MovementEngine:ScheduleDeferTask(totalAttackTime)
	self.Brain.MovementEngine:LookAt(flatTarget)
	local chargeStrafeAnimationKey = PlayChargeStrafeAnimation(self)

	local hitboxSize, hitboxOffset = GetEnemyHitboxData(self)
	local predictorSize, predictorCFrame = GetPredictorData(self, flatTarget, hitboxSize.X)
	EnemyHandler:FireAllClients("AttackPredictor", {
		UUID = attacker.UUID,
		ChargeStartedAt = workspace:GetServerTimeNow(),
		ChargeEndsAt = attackStartAt,
		ClearAt = attackStartAt,
		PredictorSize = predictorSize,
		PredictorCFrame = predictorCFrame,
	})
	EnemyHandler:FireAllClients("AttackHitbox", {
		UUID = attacker.UUID,
		ActiveFrom = attackStartAt,
		ActiveUntil = attackStartAt + self.__Attributes["AttackDuration"],
		ClearAt = workspace:GetServerTimeNow() + totalAttackTime,
		HitboxSize = hitboxSize,
		HitboxOffset = hitboxOffset,
	})

	task.delay(self.__Attributes["ChargeDuration"], function()
		if self.__Attributes["AttackToken"] ~= attackToken then
			return
		end

		if not attacker:IsAlive() then
			return
		end

		StopChargeStrafeAnimation(self, chargeStrafeAnimationKey)
		local latestFlatTarget = GetFlatTargetPosition(self, target)
		if latestFlatTarget then
			local latestDelta = latestFlatTarget - self.Brain.RootPart.Position
			attackDirection = latestDelta.Magnitude > 0.001 and latestDelta.Unit or attackDirection
			self.Brain.MovementEngine:LookAt(latestFlatTarget)
		end

		if self.Brain.MovementEngine.__Animations["Attack"] then
			self.Brain.MovementEngine:Play("Attack")
		end

		if lungeDistance > 0 then
			self.Brain.MovementEngine:ApplyLinearVelocity(attackDirection * lungeVelocity, self.__Attributes["AttackDuration"])
		end
	end)

	if attacker and targetEntity then
		local damage = attacker:GetStat("PhysicalDamage")
		local hitDelay = self.__Attributes["ChargeDuration"] + self.__Attributes["AttackDuration"]
		task.delay(hitDelay, function()
			if self.__Attributes["AttackToken"] ~= attackToken then
				return
			end

			if not attacker:IsAlive() or not targetEntity:IsAlive() then
				return
			end

			GetAttackServiceServer().ProcessEnemyHit(attacker, targetEntity, damage, self.__Attributes["AttackSwingRange"])
		end)
	end

end

local function OnExit(self: Neuron): ()
	self.__Attributes["AttackToken"] += 1
	self.Brain.MovementEngine:CancelLinearVelocity()
	self.Brain.MovementEngine:ClearLookAt()
	StopChargeStrafeAnimation(self, self.Brain.LastStrafeAnimationKey)

	if self.Brain.MovementEngine.__Animations["Attack"] then
		self.Brain.MovementEngine:Stop("Attack")
	end
end

local function OnUpdate(self: Neuron, _: number): ()
	return
end

function AttackPlayer.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Core", "AttackPlayer")
	setmetatable(self, AttackPlayer)

	self.__Attributes["AttackSwingRange"] = 4.5
	self.__Attributes["MaxLungeDistance"] = 2.5
	self.__Attributes["AttackRangeBuffer"] = 0.5
	self.__Attributes["Cooldown"] = 1.2
	self.__Attributes["ChargeDuration"] = 0.6
	self.__Attributes["Windup"] = 0
	self.__Attributes["RetreatDuration"] = 0.65
	self.__Attributes["AttackDuration"] = 0.08
	self.__Attributes["ApexPause"] = 0.12
	self.__Attributes["PredictorReachPadding"] = 2
	self.__Attributes["StrafeCarryWindow"] = 0.25
	self.__Attributes["CooldownUntil"] = 0
	self.__Attributes["ExitAt"] = 0
	self.__Attributes["AttackToken"] = 0

	return self :: any
end

return AttackPlayer
