--!strict
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationServiceServer = require(ReplicatedStorage.Services.Animation.AnimationServiceServer)
local MovementShared = require(script.Parent.MovementShared)
local EntityTypes = require(script.Parent.EntityTypes)
type Entity = EntityTypes.Entity

type SharedMovementEngine = MovementShared.SharedMovementEngine

local Handler: RemoteEvent = ReplicatedStorage.Services.Enemy:WaitForChild("EnemyHandler")

local MovementEngine = {}
MovementEngine.__index = MovementEngine
setmetatable(MovementEngine, { __index = MovementShared })

export type MovementEngine = SharedMovementEngine & {
	Character: Model,
	Humanoid: Humanoid,
	RootPart: Part,
	Speed: number,
	Entity: Entity,
	RootAttachment: Attachment?,
	MoveToFinished: CustomEvent,
	EntityUUID: string,
	FacingTarget: Vector3?,
	LookAlign: AlignOrientation?,
	__LastMoveTarget: Vector3?,
	__LastRequestedMoveTarget: Vector3?,
	__PathGoal: Vector3?,
	__PathWaypoints: { PathWaypoint }?,
	__PathComputedAt: number,
	__NextPathComputeAt: number,
	__Animations: { string: string },
	LookAt: (MovementEngine, Vector3) -> (),
	ClearLookAt: (MovementEngine) -> (),
	MoveTo: (MovementEngine, Vector3, Vector3?) -> (),
	PivotTo: (MovementEngine, CFrame) -> (),
	Play: (MovementEngine, string) -> (),
	Stop: (MovementEngine, string) -> (),
	OnLinearVelocityApplied: (MovementEngine, Vector3, number) -> (),
	OnLinearVelocityCancelled: (MovementEngine) -> (),
	Destroy: (MovementEngine) -> (),
	new: (Entity) -> MovementEngine,
	init: (MovementEngine) -> (),
}

local NAVIGATION_REPATH_INTERVAL = 0.3
local NAVIGATION_GOAL_EPSILON = 3
local DIRECT_MOVE_EPSILON = 1.5
local MAX_DESTINATION_PROBE_DISTANCE = 3
local DESTINATION_PROBE_OFFSETS = {
	Vector3.zero,
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
	Vector3.new(1, 0, 1),
	Vector3.new(1, 0, -1),
	Vector3.new(-1, 0, 1),
	Vector3.new(-1, 0, -1),
}

local function getNavigationIgnoreList(self: MovementEngine): { Instance }
	local ignoreList = { self.Character }
	local entitiesFolder = workspace:FindFirstChild("EntitiesFolder")
	if entitiesFolder then
		table.insert(ignoreList, entitiesFolder)
	end
	return ignoreList
end

local function makeNavigationRaycastParams(self: MovementEngine): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = getNavigationIgnoreList(self)
	params.RespectCanCollide = true
	return params
end

local function makeDestinationOverlapParams(self: MovementEngine): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = getNavigationIgnoreList(self)
	params.MaxParts = 32
	return params
end

local function getAgentRadius(self: MovementEngine): number
	return math.max(1.5, math.max(self.RootPart.Size.X, self.RootPart.Size.Z) * 0.5)
end

local function getAgentHeight(self: MovementEngine): number
	return math.max(4, self.RootPart.Size.Y + 2)
end

local function projectDestinationToGround(self: MovementEngine, requestedPosition: Vector3): Vector3?
	local raycastParams = makeNavigationRaycastParams(self)
	local probeRadius = math.max(1, math.min(MAX_DESTINATION_PROBE_DISTANCE, getAgentRadius(self)))
	local desiredY = requestedPosition.Y

	for _, unitOffset in ipairs(DESTINATION_PROBE_OFFSETS) do
		local offset = unitOffset * probeRadius
		local probe = requestedPosition + offset
		local rayOrigin = Vector3.new(probe.X, desiredY + 24, probe.Z)
		local groundHit = workspace:Raycast(rayOrigin, Vector3.new(0, -96, 0), raycastParams)
		if groundHit then
			local groundedPosition = Vector3.new(probe.X, groundHit.Position.Y + self.RootPart.Size.Y * 0.5, probe.Z)
			local overlapParams = makeDestinationOverlapParams(self)
			local clearanceSize = Vector3.new(
				math.max(1.5, self.RootPart.Size.X * 0.9),
				math.max(2, self.RootPart.Size.Y * 0.9),
				math.max(1.5, self.RootPart.Size.Z * 0.9)
			)
			local overlaps = workspace:GetPartBoundsInBox(CFrame.new(groundedPosition), clearanceSize, overlapParams)
			local blocked = false
			for _, part in ipairs(overlaps) do
				if part.CanCollide then
					blocked = true
					break
				end
			end

			if not blocked then
				return groundedPosition
			end
		end
	end

	return nil
end

local function hasDirectTravelPath(self: MovementEngine, destination: Vector3): boolean
	local origin = self.RootPart.Position + Vector3.new(0, math.max(1, self.RootPart.Size.Y * 0.25), 0)
	local direction = destination - origin
	if direction.Magnitude <= DIRECT_MOVE_EPSILON then
		return true
	end

	local result = workspace:Raycast(origin, direction, makeNavigationRaycastParams(self))
	return result == nil
end

local function computePathWaypoints(self: MovementEngine, destination: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath({
		AgentRadius = getAgentRadius(self),
		AgentHeight = getAgentHeight(self),
		AgentCanJump = self.Humanoid.UseJumpPower == false or self.Humanoid.JumpPower > 0,
		WaypointSpacing = math.max(3, getAgentRadius(self) * 1.5),
	})

	local ok, err = pcall(function()
		path:ComputeAsync(self.RootPart.Position, destination)
	end)
	if not ok then
		warn(string.format("[EntityMovement] Path compute failed for %s: %s", tostring(self), tostring(err)))
		return nil
	end

	if path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	local waypoints = path:GetWaypoints()
	if #waypoints == 0 then
		return nil
	end

	return waypoints
end

local function chooseMoveTargetFromPath(self: MovementEngine, destination: Vector3): (Vector3?, Enum.PathWaypointAction?)
	local now = os.clock()
	local pathGoal = self.__PathGoal
	local shouldRecompute = self.__PathWaypoints == nil
		or pathGoal == nil
		or (pathGoal - destination).Magnitude > NAVIGATION_GOAL_EPSILON
		or now >= self.__NextPathComputeAt

	if shouldRecompute then
		self.__PathGoal = destination
		self.__PathWaypoints = computePathWaypoints(self, destination)
		self.__PathComputedAt = now
		self.__NextPathComputeAt = now + NAVIGATION_REPATH_INTERVAL
	end

	local waypoints = self.__PathWaypoints
	if not waypoints then
		return nil, nil
	end

	local currentPosition = self.RootPart.Position
	local minimumAdvanceDistance = math.max(1.5, getAgentRadius(self))
	for _, waypoint in ipairs(waypoints) do
		local waypointPosition = Vector3.new(waypoint.Position.X, destination.Y, waypoint.Position.Z)
		if (waypointPosition - currentPosition).Magnitude > minimumAdvanceDistance then
			return waypointPosition, waypoint.Action
		end
	end

	return destination, waypoints[#waypoints].Action
end

local function resolveMoveTarget(self: MovementEngine, requestedPosition: Vector3): (Vector3?, Enum.PathWaypointAction?)
	local groundedDestination = projectDestinationToGround(self, requestedPosition)
	if not groundedDestination then
		self.__PathGoal = nil
		self.__PathWaypoints = nil
		return nil, nil
	end

	if hasDirectTravelPath(self, groundedDestination) then
		self.__PathGoal = nil
		self.__PathWaypoints = nil
		return groundedDestination, nil
	end

	return chooseMoveTargetFromPath(self, groundedDestination)
end

function MovementEngine.__tostring(self: MovementEngine): string
	return "MovementEngine<" .. (self.EntityUUID or self.Character.Name) .. ">"
end

function MovementEngine.init(self: MovementEngine): ()
	self.FacingTarget = nil
	self.__LastMoveTarget = nil
	self.__LastRequestedMoveTarget = nil
	self.__PathGoal = nil
	self.__PathWaypoints = nil
	self.__PathComputedAt = 0
	self.__NextPathComputeAt = 0
	MovementShared.Init(self)
	self.__SpeedChangedConnection = self.Entity:GetStatChangedSignal("Speed"):Connect(function(newValue: number)
		self.Speed = newValue
		if self:IsMovementEnabled() then
			self.Humanoid.WalkSpeed = newValue
		end
	end)
end

function MovementEngine.new(entity: Entity): MovementEngine
	local self = setmetatable({}, MovementEngine)

	self.States = {}
	self.Character = entity.Character
	self.Humanoid = entity.Character:FindFirstChild("Humanoid") :: Humanoid
	self.RootPart = entity.RootPart
	self.Entity = entity
	self.RootAttachment = self.RootPart:FindFirstChild("RootAttachment") :: Attachment?
	self.EntityUUID = entity.UUID
	self.Speed = entity:GetStat("Speed")
	self.__Animations = entity.__Animations
	self.MoveToFinished = self.Humanoid.MoveToFinished;

	local movement = (self :: any) :: MovementEngine
	movement:init()

	return movement
end

function MovementEngine.OnLinearVelocityApplied(self: MovementEngine, force: Vector3, time_: number): ()
	Handler:FireAllClients("LinearVelocity", {
		UUID = self.EntityUUID,
		Velocity = force,
		Duration = time_,
	})
end

function MovementEngine.OnLinearVelocityCancelled(self: MovementEngine): ()
	Handler:FireAllClients("CancelLinearVelocity", {
		UUID = self.EntityUUID,
	})
end

local function GetLookAlign(self: MovementEngine): AlignOrientation?
	if self.LookAlign and self.LookAlign.Parent then
		return self.LookAlign
	end

	local attachment = self.RootAttachment or self.RootPart:FindFirstChild("RootAttachment")
	if not attachment then
		return nil
	end

	local align = self.RootPart:FindFirstChild("LookAlign") :: AlignOrientation?
	if not align then
		align = Instance.new("AlignOrientation")
		align.Name = "LookAlign"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment :: Attachment
		align.Responsiveness = 200
		align.RigidityEnabled = false
		align.Enabled = false
		align.Parent = self.RootPart
	end

	self.RootAttachment = attachment :: Attachment
	self.LookAlign = align

	return align
end

local function GetAttackContext(self: MovementEngine): { [string]: any }
	local equippedWeapon = self.Entity:GetEquippedWeapon()
	local weaponClass = equippedWeapon and equippedWeapon.Class or "Punch"
	local attackContext = equippedWeapon and equippedWeapon:GetAttackContext() or {}

	if weaponClass == "Punch" then
		return {
			SightRange = 16,
			SwingRange = 3,
			MaxDashRange = 1.5,
			LungeDuration = 0.08,
			LockDuration = 0.25,
		}
	end

	local swordDefaults = {
		SightRange = 32,
		SwingRange = 4.5,
		MaxDashRange = 2.5,
		LungeDuration = 0.08,
		LockDuration = 0.35,
	}
	for key, value in pairs(swordDefaults) do
		if attackContext[key] == nil then
			attackContext[key] = value
		end
	end

	return attackContext
end

function MovementEngine.LookAt(self: MovementEngine, target: Vector3): ()
	self.FacingTarget = target
	local myPos = self.RootPart.Position
	local flatTarget = Vector3.new(target.X, myPos.Y, target.Z)
	local facingInverted = self.Character:GetAttribute("FacingInverted") == true
	if facingInverted then
		local delta = flatTarget - myPos
		if delta.Magnitude > 0.001 then
			flatTarget = myPos - delta
		end
	end
	local hasLookDirection = (flatTarget - myPos).Magnitude > 0.001
	if hasLookDirection then
		self.RootPart.CFrame = CFrame.lookAt(myPos, flatTarget)
	end

	local align = GetLookAlign(self)
	if align and hasLookDirection then
		align.CFrame = CFrame.lookAt(myPos, flatTarget)
		align.Enabled = true
		self.Humanoid.AutoRotate = false
	end

	Handler:FireAllClients("Face", {
		UUID = self.EntityUUID,
		LookAt = target,
	})
end

function MovementEngine.ClearLookAt(self: MovementEngine): ()
	self.FacingTarget = nil

	if self.LookAlign then
		self.LookAlign.Enabled = false
	end
	self.Humanoid.AutoRotate = true

	Handler:FireAllClients("Face", {
		UUID = self.EntityUUID,
		LookAt = nil,
	})
end

function MovementEngine.Attack(self: MovementEngine): ()
	if not self:IsMovementEnabled() then
		return
	end

	local attackContext = GetAttackContext(self)
	local attackSightRange = attackContext.SightRange
	local attackSwingRange = attackContext.SwingRange
	local maxLungeDistance = attackContext.MaxDashRange
	local lungeDuration = attackContext.LungeDuration
	local movementLockDuration = attackContext.LockDuration

	local target = self:GetTarget(self.RootPart.Position, attackSightRange)
	local targetLocation = Vector3.zero

	if not target then
		targetLocation = self.RootPart.Position + self.RootPart.CFrame.LookVector.Unit * attackSwingRange
	else
		targetLocation = target.RootPart.Position
	end

	self:LockMovement(movementLockDuration)

	local flatTargetLocation = Vector3.new(targetLocation.X, self.RootPart.Position.Y, targetLocation.Z)
	local delta = (flatTargetLocation - self.RootPart.Position)
	local distanceToTarget = delta.Magnitude
	local unit = distanceToTarget > 0.001 and delta.Unit or self.RootPart.CFrame.LookVector
	local lungeDistance = MovementShared.GetDesiredLungeDistance(distanceToTarget, attackSwingRange, maxLungeDistance)
	local lungeVelocity = lungeDistance / lungeDuration

	self.RootPart.CFrame = CFrame.lookAt(self.RootPart.Position, flatTargetLocation)
	if lungeDistance > 0 then
		self:ApplyLinearVelocity(unit * lungeVelocity, lungeDuration)
	end
end

function MovementEngine.Dash(self: MovementEngine): ()
	if not self:IsMovementEnabled() or not self:IsGrounded() then
		return
	end

	local dashDirection = self.RootPart.CFrame.LookVector.Unit
	self:DisableMovement()
	self:SetInvincibilityStatus(true)
	self:ScheduleDeferTask(0.3)
	self:ApplyLinearVelocity(dashDirection * 36, 0.3)
end

function MovementEngine.MoveTo(self: MovementEngine, position: Vector3, lookAt: Vector3?): ()
	if not self:IsMovementEnabled() then
		return
	end

	if lookAt then
		self:LookAt(lookAt)
	else
		self:ClearLookAt()
	end

	self.__LastRequestedMoveTarget = position
	local resolvedTarget, waypointAction = resolveMoveTarget(self, position)
	if not resolvedTarget then
		resolvedTarget = self.RootPart.Position
	end

	self.__LastMoveTarget = resolvedTarget
	if waypointAction == Enum.PathWaypointAction.Jump then
		self.Humanoid.Jump = true
	end

	self.Humanoid:MoveTo(resolvedTarget)
	Handler:FireAllClients("Move", {
		UUID = self.EntityUUID,
		Position = resolvedTarget,
		LookAt = lookAt,
	})
end

function MovementEngine.PivotTo(self: MovementEngine, cf: CFrame): ()
	if not self:IsMovementEnabled() then
		return
	end

	self.FacingTarget = nil
	self.RootPart:PivotTo(cf)
	Handler:FireAllClients("Pivot", {
		UUID = self.EntityUUID,
		CFrame = cf,
	})
end

function MovementEngine.Play(self: MovementEngine, animId: string)
	local animationId = self.__Animations[animId]
	if type(animationId) ~= "string" or animationId == "" then
		return
	end

	AnimationServiceServer.Animate(self.EntityUUID, animationId)
end

function MovementEngine.Stop(self: MovementEngine, animId: string)
	local animationId = self.__Animations[animId]
	if type(animationId) ~= "string" or animationId == "" then
		return
	end

	AnimationServiceServer.Stop(self.EntityUUID, animationId)
end

function MovementEngine.Destroy(self: MovementEngine)
	self:CancelLinearVelocity()
	self:ClearLookAt()
	self.__PathGoal = nil
	self.__PathWaypoints = nil

	if self.DeferredCancelTask then
		task.cancel(self.DeferredCancelTask)
		self.DeferredCancelTask = nil
	end

	if self.__SpeedChangedConnection then
		self.__SpeedChangedConnection:Disconnect()
		self.__SpeedChangedConnection = nil
	end
end

return MovementEngine
