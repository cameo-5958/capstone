--!strict
local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)

type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local __New_Neuron = {}
__New_Neuron.__index = __New_Neuron
setmetatable(__New_Neuron, SuperNeuron)

--

local function GetStrafeAnimationKey(self: Neuron): string
	return self.__Attributes["Direction"] == 1 and "StrafeRight" or "StrafeLeft"
end

local function CanEnter(self: Neuron): boolean
	local target = self.Brain.Target
	if not target then
		return false
	end

	local dist = self.Brain:Delta(target).Magnitude
	local range = self.__Attributes["AttackRange"]

	if self.Brain.PendingStrafes > 0 then
		return dist < range * 2
	end

	-- Only strafe if we are within a reasonable "combat" distance
	if dist < range * 1.5 then
		-- Cumulative chance: more strafes = higher chance to stop and attack
		local chance = 1 - (self.__Attributes["Strafes"] * 0.3)
		return math.random() < chance
	end
	return false
end

local function CanExit(self: Neuron): boolean
	if not self.Brain.Target then
		return true
	end

	-- Exit if we've strafed long enough or player ran away
	local duration = tick() - self.__Attributes["StartTime"]
	local tooFar = self.Brain:Delta(self.Brain.Target).Magnitude > self.__Attributes["AttackRange"] * 2

	return duration >= self.__Attributes["MaxDuration"] or tooFar
end

local function OnEnter(self: Neuron): ()
	self.__Attributes["Strafes"] += 1
	self.__Attributes["StartTime"] = tick()
	self.__Attributes["MaxDuration"] = self.__Attributes["MinDuration"]
		+ math.random() * (self.__Attributes["MaxDurationRange"] - self.__Attributes["MinDuration"])
	self.__Attributes["PreviousWalkSpeed"] = self.Brain.MovementEngine.Humanoid.WalkSpeed
	self.Brain.MovementEngine.Humanoid.WalkSpeed = self.__Attributes["StrafeWalkSpeed"]

	-- Pick a direction: 1 for Right, -1 for Left
	self.__Attributes["Direction"] = math.random() > 0.5 and 1 or -1

	local animationKey = GetStrafeAnimationKey(self)
	if self.Brain.MovementEngine.__Animations[animationKey] then
		self.Brain.MovementEngine:Play(animationKey)
	end
end

local function OnUpdate(self: Neuron, _: number): ()
	local targetPart = self.Brain.Target.PrimaryPart :: Part

	local targetPos = targetPart.Position
	local myPos = self.Brain.RootPart.Position

	-- 1. Flatten both positions to the XZ plane so Y doesn't contaminate direction math
	local flatTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
	local toPlayer = (flatTarget - myPos).Unit

	-- 2. toPlayer:Cross(Up) gives the TRUE right-hand strafe vector facing the player
	--    (the original Up:Cross(toPlayer) was inverted, causing backwards strafing)
	local sideVector = toPlayer:Cross(Vector3.new(0, 1, 0))
	local strafeDir = sideVector * self.__Attributes["Direction"]

	-- 3. Distance maintenance — push/pull along the flat toPlayer axis
	local currentDist = (flatTarget - myPos).Magnitude
	local desiredDist = self.__Attributes["DesiredDistance"]
	local depthCorrection = toPlayer * (currentDist - desiredDist)

	-- 4. Combine strafe + depth correction and project to a goal position
	local combined = strafeDir + depthCorrection * 0.5
	local moveVector = combined.Magnitude > 0.001 and combined.Unit or strafeDir
	local goalPos = myPos + moveVector * self.__Attributes["StepDistance"]

	-- 5. Lock the NPC's facing toward the player while strafing
	self.Brain.MovementEngine:MoveTo(goalPos, flatTarget)
end

local function OnExit(self: Neuron): ()
	local animationKey = GetStrafeAnimationKey(self)
	if self.Brain.MovementEngine.__Animations[animationKey] then
		self.Brain.MovementEngine:Stop(animationKey)
	end

	self.Brain.MovementEngine.Humanoid.WalkSpeed = self.__Attributes["PreviousWalkSpeed"]
	if self.Brain.PendingStrafes > 0 then
		self.Brain.PendingStrafes -= 1
	end
end

function __New_Neuron.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Core", "StrafePlayer")
	setmetatable(self, __New_Neuron)

	self.__Attributes["Strafes"] = 0
	self.__Attributes["AttackRange"] = 10
	self.__Attributes["Direction"] = 1
	self.__Attributes["StartTime"] = 0
	self.__Attributes["MaxDuration"] = 0
	self.__Attributes["StepDistance"] = 2
	self.__Attributes["DesiredDistance"] = 7
	self.__Attributes["StrafeWalkSpeed"] = 6
	self.__Attributes["PreviousWalkSpeed"] = 0
	self.__Attributes["MinDuration"] = 0.45
	self.__Attributes["MaxDurationRange"] = 0.9

	return self :: any
end

return __New_Neuron
