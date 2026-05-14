--!strict

local SuperNeuron = require(script.Parent.Parent.Neuron)
local BrainTypes = require(script.Parent.Parent.BrainTypes)
local PlayerServiceServer = require(game:GetService("ReplicatedStorage").Services.Player.PlayerServiceServer)

type Neuron = BrainTypes.Neuron

local EscapePlayer = {}
EscapePlayer.__index = EscapePlayer
setmetatable(EscapePlayer, SuperNeuron)

local SPEED_MODIFIER_ID = "brain:escape:speed"
local RUN_START_WARN_WINDOW_SECONDS = 0.75
local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
RAYCAST_PARAMS.FilterDescendantsInstances = { workspace:FindFirstChild("EntitiesFolder") or workspace }
RAYCAST_PARAMS.RespectCanCollide = true

local function GetEscapeTarget(self: Neuron): Model?
	if workspace:GetServerTimeNow() > self.Brain.EscapeUntil then
		return nil
	end
	return self.Brain.EscapeTarget
end

local function CanEnter(self: Neuron): boolean
	return GetEscapeTarget(self) ~= nil and self.Brain.CurrentNeuron ~= self
end

local function CanExit(self: Neuron): boolean
	return GetEscapeTarget(self) == nil
end

local function ComputeRunLocation(self: Neuron, targetCharacter: Model): Vector3
	local myPos = self.Brain.RootPart.Position
	local targetRoot = targetCharacter.PrimaryPart
	local targetPos = if targetRoot then targetRoot.Position else myPos
	local flatSelf = Vector3.new(myPos.X, myPos.Y, myPos.Z)
	local flatTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
	local away = flatSelf - flatTarget
	if away.Magnitude <= 0.001 then
		away = self.Brain.RootPart.CFrame.LookVector
	end
	local runTo = flatSelf + away.Unit * self.__Attributes["RunDistance"]
	local probeStart = runTo + Vector3.new(0, 24, 0)
	local ray = workspace:Raycast(probeStart, Vector3.new(0, -96, 0), RAYCAST_PARAMS)
	if ray then
		return Vector3.new(runTo.X, ray.Position.Y + 2, runTo.Z)
	end
	return runTo
end

local function OnEnter(self: Neuron): ()
	local movement = self.Brain.MovementEngine
	local entity = movement.Entity
	local now = workspace:GetServerTimeNow()

	if self.__Attributes["SpeedHandle"] == nil then
		self.__Attributes["SpeedHandle"] = entity:AddModifier("Speed", entity.Modifier.new(
			SPEED_MODIFIER_ID,
			"Multiplicative",
			2,
			"brain:escape"
		))
	end

	movement:Stop("Walk")
	movement:ClearLookAt()
	local timeSinceLastRunStart = now - self.__Attributes["LastRunStartAt"]
	if not self.__Attributes["RunPlaying"] then
		if timeSinceLastRunStart < RUN_START_WARN_WINDOW_SECONDS then
			print(string.format(
				"[EscapePlayer] Run start quick-succession warning uuid=%s dt=%.3f at=%.3f",
				movement.EntityUUID,
				timeSinceLastRunStart,
				now
			))
		end
		movement:Play("Run")
		self.__Attributes["RunPlaying"] = true
		self.__Attributes["LastRunStartAt"] = now
		print(string.format("[EscapePlayer] Run start uuid=%s at=%.3f", movement.EntityUUID, now))
	elseif self.__Attributes["RunPlaying"] then
		print(string.format("[EscapePlayer] Run start skipped (already playing) uuid=%s at=%.3f", movement.EntityUUID, now))
	end
	self.__Attributes["NextRepathAt"] = 0
	self.__Attributes["LastRunTo"] = nil
end

local function OnExit(self: Neuron): ()
	local movement = self.Brain.MovementEngine
	local entity = movement.Entity

	if self.__Attributes["SpeedHandle"] ~= nil then
		entity:RemoveModifierHandle(self.__Attributes["SpeedHandle"])
		self.__Attributes["SpeedHandle"] = nil
	end

	if self.__Attributes["RunPlaying"] then
		movement:Stop("Run")
		self.__Attributes["RunPlaying"] = false
		print(string.format("[EscapePlayer] Run stop uuid=%s at=%.3f", movement.EntityUUID, workspace:GetServerTimeNow()))
	end
	movement:MoveTo(self.Brain.RootPart.Position)
	movement:ClearLookAt()
end

local function OnUpdate(self: Neuron, _: number): ()
	local targetCharacter = GetEscapeTarget(self)
	if not targetCharacter then
		return
	end

	local playerEntity = PlayerServiceServer.GetEntityFromCharacter(targetCharacter)
	if not playerEntity or not playerEntity:IsAlive() then
		self.Brain.EscapeTarget = nil
		self.Brain.EscapeUntil = 0
		return
	end

	local now = workspace:GetServerTimeNow()
	if now < self.__Attributes["NextRepathAt"] then
		return
	end

	local runTo = ComputeRunLocation(self, targetCharacter)
	local lastRunTo: Vector3? = self.__Attributes["LastRunTo"]
	if lastRunTo and (runTo - lastRunTo).Magnitude < 4 then
		self.__Attributes["NextRepathAt"] = now + 0.35
		return
	end

	self.Brain.MovementEngine:MoveTo(runTo)
	self.__Attributes["LastRunTo"] = runTo
	self.__Attributes["NextRepathAt"] = now + 0.35
end

function EscapePlayer.new(): Neuron
	local self = SuperNeuron.new(CanEnter, CanExit, OnEnter, OnExit, OnUpdate, "Interrupting", "EscapePlayer")
	setmetatable(self, EscapePlayer)

	self.__Attributes["RunDistance"] = 18
	self.__Attributes["SpeedHandle"] = nil
	self.__Attributes["RunPlaying"] = false
	self.__Attributes["LastRunStartAt"] = -math.huge
	self.__Attributes["NextRepathAt"] = 0
	self.__Attributes["LastRunTo"] = nil

	return self :: any
end

return EscapePlayer
