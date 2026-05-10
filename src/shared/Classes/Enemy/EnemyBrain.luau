--!strict
-- EnemyBrain.luau defines the logic that
-- brains use

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Movement = require(ReplicatedStorage.Classes.Entity.EntityMovement)
local BrainTypes = require(ReplicatedStorage.Classes.Enemy.BrainTypes)

type MovementEngine = Movement.MovementEngine
type Brain = BrainTypes.Brain
type Neuron = BrainTypes.Neuron

local Brain = {}
Brain.__index = Brain
local PlayerServiceServerModule = nil :: any

local function GetPlayerServiceServerModule()
	if PlayerServiceServerModule == nil then
		PlayerServiceServerModule = require(ReplicatedStorage.Services.Player:WaitForChild("PlayerServiceServer") :: ModuleScript)
	end

	return PlayerServiceServerModule
end

-- Constructor
function Brain.new(movementEngine: MovementEngine, neurons: { Neuron }): Brain
	local self = setmetatable({}, Brain)

	self.MovementEngine = movementEngine
	self.Character = movementEngine.Character
	self.RootPart = movementEngine.RootPart

	-- Initialize Neurons
	self.Neurons = neurons
	for _, neuron in neurons do
		neuron.Brain = (self :: any) :: Brain
	end

	-- Initialize state
	self.LastEnteredState = 0
	self.CurrentNeuron = nil

	-- Aggro
	self.Aggro = false
	self.RetreatTarget = nil
	self.RetreatUntil = 0
	self.PendingStrafes = 0
	self.PendingStumble = false
	self.StumbleSourcePosition = nil
	self.LastStrafeAnimationKey = nil
	self.LastStrafeEndedAt = 0

	return self :: any
end

-- Go and Stop
function Brain.Go(self: Brain)
	-- Begin a RunService loop
	self.__Thread = RunService.Heartbeat:Connect(function(dt)
		self:Tick(dt)
	end)
end

function Brain.Stop(self: Brain)
	if self.__Thread then
		self.__Thread:Disconnect()
		self.__Thread = nil
	end
end

function Brain.Destroy(self: Brain)
	self:Stop()

	if self.CurrentNeuron then
		self.CurrentNeuron:OnExit()
		self.CurrentNeuron = nil
	end

	self.Target = nil
	self.RetreatTarget = nil
	self.RetreatUntil = 0
	self.PendingStrafes = 0
	self.PendingStumble = false
	self.StumbleSourcePosition = nil
	self.LastStrafeAnimationKey = nil
	self.LastStrafeEndedAt = 0
end

function Brain.QueueStumble(self: Brain, sourcePosition: Vector3?)
	self.PendingStumble = true
	self.StumbleSourcePosition = sourcePosition
end

-- Brain thread
function Brain.Tick(self: Brain, dt: number)
	local PlayerServiceServer = GetPlayerServiceServerModule()

	if self.Target then
		local targetEntity = PlayerServiceServer.GetEntityFromCharacter(self.Target)
		if not targetEntity or not targetEntity:IsAlive() then
			self.Target = nil
		end
	end

	if self.RetreatTarget then
		local retreatEntity = PlayerServiceServer.GetEntityFromCharacter(self.RetreatTarget)
		if not retreatEntity or not retreatEntity:IsAlive() then
			self.RetreatTarget = nil
			self.RetreatUntil = 0
		end
	end

	-- Check if we should exist the current state
	if self.CurrentNeuron then
		if self.CurrentNeuron.CanExit(self.CurrentNeuron) then
			self.CurrentNeuron.OnExit(self.CurrentNeuron)
			self.LastEnteredState = os.clock()
			self.CurrentNeuron = nil
		end
	end

	-- Regardless of if we have a state, if there is an
	-- interrupting state, we must enter it
	for _, neuron in self.Neurons do
		if neuron.Priority == "Interrupting" and neuron:CanEnter() then
			-- Exit the current neuron, if any
			if self.CurrentNeuron then
				self.CurrentNeuron:OnExit()
			end

			neuron:OnEnter()
			self.CurrentNeuron = neuron
			break
		end
	end

	-- If we don't have a state, check if we can enter one
	-- in order of priority: Interrupting > Core > Idle
	if not self.CurrentNeuron then
		for _, state in ipairs({ "Core", "Idle" }) do
			for _, neuron in self.Neurons do
				if neuron.Priority == state and neuron:CanEnter() then
					neuron:OnEnter()
					self.CurrentNeuron = neuron
					break
				end
			end
			if self.CurrentNeuron then
				break
			end
		end
	end

	-- Update the current state
	if self.CurrentNeuron then
		self.CurrentNeuron:OnUpdate(dt)
	end
end

-- Raycast for Enemy Vision
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = { workspace:WaitForChild("EntitiesFolder") }
-- Any utility methods used by neurons
function Brain.HitPlayer(self: Brain, player: Model, range: number): boolean
	-- Grab player position
	local pos = self.RootPart.Position
	local playerPos = (player.PrimaryPart :: Part).Position

	-- Raycast here
	local result = workspace:Raycast(pos, (playerPos - pos).Unit * range, raycastParams)

	if not result then
		return false
	end

	return result.Instance:IsDescendantOf(player)
end

function Brain.Obstruction(self: Brain, pos: Vector3): boolean
	-- Raycast
	local myPos = self.RootPart.Position
	local result = workspace:Raycast(pos, myPos - pos, raycastParams)

	return result
end

function Brain.GetTargetPlayer(self: Brain, range: number): Model?
	local PlayerServiceServer = GetPlayerServiceServerModule()

	-- Get list of players
	local plys = PlayerServiceServer.GetPlayers()

	local highestScore = -1
	local hitModel = nil
	for _, player in pairs(plys) do
		if not player:IsAlive() then
			continue
		end

		-- Ensure model exists
		local model = player.Character
		if not model then
			continue
		end

		-- Fire a raycast to ensure this player
		-- is detected
		if self:HitPlayer(model, range) then
			local score = range - (self.RootPart.Position - (model.PrimaryPart :: Part).Position).Magnitude

			if score > highestScore then
				highestScore = score
				hitModel = model
			end
		end
	end

	return hitModel
end

function Brain.Delta(self: Brain, player: Model): Vector3
	local myPos = self.RootPart.Position
	local playerPos = (player.PrimaryPart :: Part).Position

	return (myPos - playerPos)
end

return Brain
