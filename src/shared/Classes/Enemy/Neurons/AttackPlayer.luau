--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)

type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local AttackPlayer = {}
AttackPlayer.__index = AttackPlayer
setmetatable(AttackPlayer, SuperNeuron)

local function GetDesiredLungeDistance(self: Neuron, distanceToTarget: number): number
	return math.min(
		self.__Attributes["MaxLungeDistance"],
		math.max(0, distanceToTarget - self.__Attributes["AttackSwingRange"])
	)
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

	local targetPos = target.PrimaryPart.Position
	local attacker = self.Brain.MovementEngine.Entity
	local targetEntity = PlayerServiceServer.GetEntityFromCharacter(target)
	local totalAttackTime = self.__Attributes["Windup"] + self.__Attributes["AttackDuration"] + self.__Attributes["ApexPause"]

	self.__Attributes["ExitAt"] = os.clock() + totalAttackTime
	self.__Attributes["CooldownUntil"] = os.clock() + self.__Attributes["Cooldown"]
	self.Brain.RetreatTarget = target
	self.Brain.RetreatUntil = os.clock() + self.__Attributes["RetreatDuration"]

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
	if lungeDistance > 0 then
		self.Brain.MovementEngine:ApplyLinearVelocity(attackDirection * lungeVelocity, self.__Attributes["AttackDuration"])
	end

	if attacker and targetEntity then
		local damage = attacker:GetStat("PhysicalAttack") + attacker:GetStat("Strength")
		attacker:ApplyDamage(damage, targetEntity)
	end

	if self.Brain.MovementEngine.__Animations["Attack"] then
		self.Brain.MovementEngine:Play("Attack")
	end
end

local function OnExit(self: Neuron): ()
	self.Brain.MovementEngine:ClearLookAt()

	if self.Brain.MovementEngine.__Animations["Attack"] then
		self.Brain.MovementEngine:Stop("Attack")
	end
end

local function OnUpdate(self: Neuron, _: number): ()
	local target = self.Brain.Target
	if not target or not target.PrimaryPart then
		return
	end

	self.Brain.MovementEngine:LookAt(target.PrimaryPart.Position)
end

function AttackPlayer.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Core", "AttackPlayer")
	setmetatable(self, AttackPlayer)

	self.__Attributes["AttackSwingRange"] = 4.5
	self.__Attributes["MaxLungeDistance"] = 2.5
	self.__Attributes["AttackRangeBuffer"] = 0.5
	self.__Attributes["Cooldown"] = 1.2
	self.__Attributes["Windup"] = 0.35
	self.__Attributes["RetreatDuration"] = 0.65
	self.__Attributes["AttackDuration"] = 0.08
	self.__Attributes["ApexPause"] = 0.12
	self.__Attributes["CooldownUntil"] = 0
	self.__Attributes["ExitAt"] = 0

	return self :: any
end

return AttackPlayer
