--!strict

local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)

type Neuron = BrainTypes.Neuron

local BackOffPlayer = {}
BackOffPlayer.__index = BackOffPlayer
setmetatable(BackOffPlayer, SuperNeuron)

local function CanEnter(self: Neuron): boolean
	local target = self.Brain.RetreatTarget
	if not target or not target.PrimaryPart then
		return false
	end

	return os.clock() < self.Brain.RetreatUntil
end

local function CanExit(self: Neuron): boolean
	local target = self.Brain.RetreatTarget
	if not target then
		return os.clock() >= self.Brain.RetreatUntil
	end

	local distance = self.Brain:Delta(target).Magnitude
	return os.clock() >= self.Brain.RetreatUntil and distance >= self.__Attributes["DesiredDistance"]
end

local function OnEnter(self: Neuron): ()
	self.__Attributes["StartedAt"] = os.clock()

	if self.Brain.MovementEngine.__Animations["Walk"] then
		self.Brain.MovementEngine:Play("Walk")
	end
end

local function OnExit(self: Neuron): ()
	self.Brain.RetreatTarget = nil
	self.Brain.RetreatUntil = 0
	self.Brain.PendingStrafes = math.random(
		self.__Attributes["MinStrafesAfterBackOff"],
		self.__Attributes["MaxStrafesAfterBackOff"]
	)
	self.Brain.MovementEngine:ClearLookAt()

	if self.Brain.MovementEngine.__Animations["Walk"] then
		self.Brain.MovementEngine:Stop("Walk")
	end
end

local function OnUpdate(self: Neuron, _: number): ()
	local target = self.Brain.RetreatTarget
	if not target or not target.PrimaryPart then
		return
	end

	local myPos = self.Brain.RootPart.Position
	local targetPos = target.PrimaryPart.Position
	local flatTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
	local away = myPos - flatTarget
	local moveDir = away.Magnitude > 0.001 and away.Unit or -self.Brain.RootPart.CFrame.LookVector
	local destination = myPos + moveDir * self.__Attributes["StepDistance"]

	self.Brain.MovementEngine:MoveTo(destination, flatTarget)
end

function BackOffPlayer.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Core", "BackOffPlayer")
	setmetatable(self, BackOffPlayer)

	self.__Attributes["DesiredDistance"] = 8
	self.__Attributes["StepDistance"] = 5
	self.__Attributes["StartedAt"] = 0
	self.__Attributes["MinStrafesAfterBackOff"] = 2
	self.__Attributes["MaxStrafesAfterBackOff"] = 5

	return self :: any
end

return BackOffPlayer
