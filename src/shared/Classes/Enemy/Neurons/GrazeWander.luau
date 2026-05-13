--!strict

local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)

type Neuron = BrainTypes.Neuron

local GrazeWander = {}
GrazeWander.__index = GrazeWander
setmetatable(GrazeWander, SuperNeuron)
local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
RAYCAST_PARAMS.FilterDescendantsInstances = { workspace:FindFirstChild("EntitiesFolder") or workspace }

local function snapToGround(x: number, z: number, fallbackY: number): Vector3
	local start = Vector3.new(x, fallbackY + 24, z)
	local ray = workspace:Raycast(start, Vector3.new(0, -96, 0), RAYCAST_PARAMS)
	if ray then
		return Vector3.new(x, ray.Position.Y + 2, z)
	end
	return Vector3.new(x, fallbackY, z)
end

local function pickTarget(self: Neuron): Vector3
	local origin = self.Brain.RootPart.Position
	for _ = 1, 24 do
		local delta = Vector3.new(math.random(-self.__Attributes["Range"], self.__Attributes["Range"]), 0, math.random(-self.__Attributes["Range"], self.__Attributes["Range"]))
		local candidateFlat = origin + delta
		local candidate = snapToGround(candidateFlat.X, candidateFlat.Z, origin.Y)
		local planarDistance = Vector3.new(candidate.X - origin.X, 0, candidate.Z - origin.Z).Magnitude
		if planarDistance >= 6 then
			return candidate
		end
	end
	local fallback = origin + Vector3.new(self.__Attributes["Range"] * 0.5, 0, 0)
	return snapToGround(fallback.X, fallback.Z, origin.Y)
end

local function CanEnter(_: Neuron): boolean
	return true
end

local function CanExit(self: Neuron): boolean
	return self.__Attributes["ExitAt"] <= os.clock()
end

local function OnEnter(self: Neuron): ()
	local shouldPause = math.random() < self.__Attributes["PauseChance"]
	self.__Attributes["Arrived"] = shouldPause

	if shouldPause then
		self.__Attributes["TargetLocation"] = self.Brain.RootPart.Position
		self.__Attributes["ExitAt"] = os.clock() + math.random(900, 2200) / 1000
		self.Brain.MovementEngine:MoveTo(self.Brain.RootPart.Position)
		self.Brain.MovementEngine:Stop("Walk")
		return
	end

	local target = pickTarget(self)
	self.__Attributes["TargetLocation"] = target
	self.__Attributes["ExitAt"] = os.clock() + math.random(2500, 5000) / 1000
	self.__Attributes["Arrived"] = false

	local finishedConnection = self.__Attributes["MoveToFinished"]
	if finishedConnection then
		finishedConnection:Disconnect()
	end
	self.__Attributes["MoveToFinished"] = self.Brain.MovementEngine.MoveToFinished:Connect(function(reached: boolean)
		if reached then
			self.__Attributes["Arrived"] = true
			self.Brain.MovementEngine:Stop("Walk")
		end
	end)

	self.Brain.MovementEngine:MoveTo(target)
	self.Brain.MovementEngine:Play("Walk")
end

local function OnExit(self: Neuron): ()
	local finishedConnection = self.__Attributes["MoveToFinished"]
	if finishedConnection then
		finishedConnection:Disconnect()
		self.__Attributes["MoveToFinished"] = nil
	end
	self.Brain.MovementEngine:MoveTo(self.Brain.RootPart.Position)
	self.Brain.MovementEngine:Stop("Walk")
end

local function OnUpdate(self: Neuron, _: number): ()
	if self.__Attributes["Arrived"] == true then
		self.Brain.MovementEngine:Stop("Walk")
	end
end

function GrazeWander.new(range: number): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Idle", "GrazeWander")
	setmetatable(self, GrazeWander)
	self.__Attributes["Range"] = math.max(8, math.floor(range * 0.5))
	self.__Attributes["TargetLocation"] = nil
	self.__Attributes["ExitAt"] = 0
	self.__Attributes["Arrived"] = false
	self.__Attributes["MoveToFinished"] = nil
	self.__Attributes["PauseChance"] = 0.35
	return self :: any
end

return GrazeWander
