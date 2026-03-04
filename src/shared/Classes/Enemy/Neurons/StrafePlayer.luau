--!strict
local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)

type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local __New_Neuron = {}
__New_Neuron.__index = __New_Neuron
setmetatable(__New_Neuron, SuperNeuron)

local function CanEnter(self: Neuron): boolean
	if not self.Brain.Target then
		return false
	end

	local dist = self.Brain:Delta(self.Brain.Target).Magnitude
	local range = self.__Attributes["AttackRange"]

	-- Try to strafe if in range
	if dist < range * 1.5 then
		if self.__Attributes["Strafes"] < 2 then
			return true
		else
			self.__Attributes["Strafes"] = 0 -- Failed roll, proceed to attack
		end
	end
	return false
end

local function CanExit(self: Neuron): boolean
	if not self.Brain.Target then
		return true
	end

	-- Calculate how much rotation is left
	local current = self.__Attributes["CurrentTheta"]
	local target = self.__Attributes["TargetTheta"]
	local dir = self.__Attributes["Direction"]

	-- If moving clockwise (1), exit when current >= target
	-- If counter-clockwise (-1), exit when current <= target
	local isFinished = if dir == 1 then current >= target else current <= target
	local tooFar = self.Brain:Delta(self.Brain.Target).Magnitude > self.__Attributes["AttackRange"] * 2

	return isFinished or tooFar
end

local function OnEnter(self: Neuron): ()
	self.__Attributes["Strafes"] += 1

	-- Calculate starting angle from current world position
	local rel = -self.Brain:Delta(self.Brain.Target)
	local startTheta = math.atan2(rel.Z, rel.X)

	local direction = math.random() > 0.5 and 1 or -1

	-- Random arc between 15 and 45 degrees
	self.__Attributes["Direction"] = direction
	self.__Attributes["TargetDeltaTheta"] = math.pi * 10 / math.random(40, 120)
end

local function OnUpdate(self: Neuron, dt: number): ()
	local targetPart = self.Brain.Target.PrimaryPart :: Part
	local radius = self.__Attributes["AttackRange"]
	local dir = self.__Attributes["Direction"]

	-- Calculate angular velocity: (Speed / Radius) = Radians per second
	-- We divide by 1.5 or 2 to make the circle a bit wider/slower if needed
	local angularVelocity = (self.Brain.MovementEngine.Speed / radius)
	self.__Attributes["CurrentTheta"] += angularVelocity * dt * dir

	local theta = self.__Attributes["CurrentTheta"]
	local offset = Vector3.new(math.cos(theta), 0, math.sin(theta)) * radius
	local goalPos = targetPart.Position + offset

	-- MoveTo allows the Roblox Humanoid to handle the legs and smoothing
	self.Brain.MovementEngine:MoveTo(goalPos)
end

local function OnExit(_: Neuron): ()
	-- Stop the humanoid movement when exiting the state
	-- self.Brain.NPC.Humanoid:MoveTo(self.Brain.NPC.PrimaryPart.Position)
end

function __New_Neuron.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Core")
	setmetatable(self, __New_Neuron)

	self.__Attributes["Strafes"] = 0
	self.__Attributes["AttackRange"] = 8 -- Increased for better strafing visualization
	return self :: any
end

return __New_Neuron
