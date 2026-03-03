--!strict

-- Import Neuron
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Behavior = require(ReplicatedStorage.Modules.Behavior.Behavior)
local PlayerServiceServer = require(ReplicatedStorage.Services.Player.PlayerServiceServer)
local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)

type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

-- Create the subclass
local __New_Neuron = {}
__New_Neuron.__index = __New_Neuron
setmetatable(__New_Neuron, SuperNeuron)

-- Neuron methods
local function CanEnter(self: Neuron): boolean
	-- Entering gateway
	-- Check all players and see if they are visible

	local target = self.Brain:GetTargetPlayer(self.__Attributes["Range"])

	if target and self.Brain:Delta(target).Magnitude > (4 + 0.5) then
		self.__Attributes["Target"] = target
		self.__Attributes["TargetPos"] = (target.PrimaryPart :: Part).Position

		self.Brain.Target = target

		return true
	end

	return false
end

local function CanExit(self: Neuron): boolean
	-- Exiting gateway
	-- If I
	-- - 'm within 4 units
	-- - reached my Wait point and can't see

	if self.Brain:Delta(self.__Attributes["Target"]).Magnitude < (4 + 0.5) then
		return true
	elseif not self.__Attributes["Moving"] then
		return true
	end
	return false
end

local function RecalculateTargetPos(self: Neuron): ()
	-- Try hitting player
	if self.Brain:HitPlayer(self.__Attributes["Target"], self.__Attributes["Range"]) then
		local playerPos = (self.__Attributes["Target"].PrimaryPart :: Part).Position

		-- Calculate target location to move to
		self.__Attributes["TargetPos"] = playerPos + self.Brain:Delta(self.__Attributes["Target"]).Unit * 4

		-- Move to that target position
		self.Brain.MovementEngine:MoveTo(self.__Attributes["TargetPos"])
	end
	-- Move to that target position
	-- self.Brain.MovementEngine:MoveTo(self.__Attributes["TargetPos"])
end

local function OnEnter(self: Neuron): ()
	-- Entering logic
	-- Begin walking to the Target position

	-- Recalculate positions if possible
	RecalculateTargetPos(self)

	-- Move to that target position
	self.Brain.MovementEngine:MoveTo(self.__Attributes["TargetPos"])
	self.__Attributes["Moving"] = true

	-- Set Moving to false if MoveTo finishes
	self.__Attributes["MoveToFinished"] = self.Brain.MovementEngine.MoveToFinished:Connect(function()
		self.__Attributes["Moving"] = false
		self.__Attributes["MoveToFinished"]:Disconnect()
	end)
end

local function OnExit(self: Neuron): ()
	-- Exiting logic
	-- Disconnect the previous MoveTo event
	self.Brain.MovementEngine:MoveTo(self.Brain.RootPart.Position)
	self.__Attributes["Moving"] = false

	self.__Attributes["MoveToFinished"]:Disconnect()
end

local function OnUpdate(self: Neuron, _: number): ()
	-- Recalculate positions if possible
	RecalculateTargetPos(self)

	-- Move to that target position
	self.Brain.MovementEngine:MoveTo(self.__Attributes["TargetPos"])
	self.__Attributes["Moving"] = true
end

-- Neuron constructor
function __New_Neuron.new(range: number): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Core")

	setmetatable(self, __New_Neuron)
	self.__Attributes["Range"] = range + 4
	return self :: any
end

-- Return the class
return __New_Neuron
