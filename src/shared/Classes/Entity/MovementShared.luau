--!strict
local RunService = game:GetService("RunService")

local MovementShared = {}

export type SharedMovementEngine = {
	Character: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	Speed: number,
	MovementEnabled: boolean,
	AllMovementDisabled: boolean?,
	Invincible: boolean,
	DeferredCancelTask: thread?,
	DeferredVelocityCancelTask: thread?,
	ApplyLinearVelocity: (SharedMovementEngine, Vector3, number) -> (),
	CancelLinearVelocity: (SharedMovementEngine) -> (),
	DeferTask: (SharedMovementEngine) -> (),
	ScheduleDeferTask: (SharedMovementEngine, number) -> (),
	SetInvincibilityStatus: (SharedMovementEngine, boolean) -> (),
	DisableMovement: (SharedMovementEngine) -> (),
	LockMovement: (SharedMovementEngine, number) -> (),
	UnlockMovement: (SharedMovementEngine) -> (),
	IsMovementEnabled: (SharedMovementEngine) -> boolean,
	IsGrounded: (SharedMovementEngine) -> boolean,
	OnLinearVelocityApplied: ((SharedMovementEngine, Vector3, number) -> ())?,
	OnLinearVelocityCancelled: ((SharedMovementEngine) -> ())?,
	UpdateMovementAnimation: ((SharedMovementEngine) -> ())?,
}

function MovementShared.GetDesiredLungeDistance(distanceToTarget: number, swingRange: number, maxLungeDistance: number): number
	return math.min(maxLungeDistance, math.max(0, distanceToTarget - swingRange))
end

function MovementShared.Init(self: SharedMovementEngine)
	self.MovementEnabled = true
	self.Invincible = false
	if self.AllMovementDisabled == nil then
		self.AllMovementDisabled = false
	end
	self:DeferTask()
end

function MovementShared.ApplyLinearVelocity(self: SharedMovementEngine, force: Vector3, time_: number)
	local lv = self.Character:FindFirstChild("LinearVelocity") :: LinearVelocity or Instance.new("LinearVelocity")
	lv.Parent = self.Character
	self.RootPart.AssemblyLinearVelocity = Vector3.zero
	lv.VectorVelocity = force
	lv.Attachment0 = self.RootPart:FindFirstChild("RootAttachment") :: Attachment
	lv.MaxForce = 999999

	if self.DeferredVelocityCancelTask then
		task.cancel(self.DeferredVelocityCancelTask)
	end

	self.DeferredVelocityCancelTask = task.delay(time_, function()
		self.DeferredVelocityCancelTask = nil

		local activeLv = self.Character:FindFirstChild("LinearVelocity")
		if activeLv then
			activeLv:Destroy()
		end
		self.RootPart.AssemblyLinearVelocity = Vector3.zero
	end)

	if self.OnLinearVelocityApplied then
		self:OnLinearVelocityApplied(force, time_)
	end
end

function MovementShared.CancelLinearVelocity(self: SharedMovementEngine)
	if self.DeferredVelocityCancelTask then
		task.cancel(self.DeferredVelocityCancelTask)
		self.DeferredVelocityCancelTask = nil
	end

	local lv = self.Character:FindFirstChild("LinearVelocity")
	if lv then
		lv:Destroy()
	end
	self.RootPart.AssemblyLinearVelocity = Vector3.zero

	if self.OnLinearVelocityCancelled then
		self:OnLinearVelocityCancelled()
	end
end

function MovementShared.SetInvincibilityStatus(self: SharedMovementEngine, status: boolean)
	if RunService:IsServer() then
		print("Server:", status)
	else
		print("Client:", status)
	end

	self.Invincible = status
end

function MovementShared.DisableMovement(self: SharedMovementEngine)
	self.MovementEnabled = false
	self.Humanoid.WalkSpeed = 0
	if self.UpdateMovementAnimation then
		self:UpdateMovementAnimation()
	end
end

function MovementShared.DeferTask(self: SharedMovementEngine)
	if self.AllMovementDisabled then
		self.MovementEnabled = false
		self.Humanoid.WalkSpeed = 0
		self:SetInvincibilityStatus(false)
		self:CancelLinearVelocity()
		if self.UpdateMovementAnimation then
			self:UpdateMovementAnimation()
		end
		return
	end

	self.MovementEnabled = true
	self:SetInvincibilityStatus(false)
	self.Humanoid.WalkSpeed = self.Speed
	self:CancelLinearVelocity()
	if self.UpdateMovementAnimation then
		self:UpdateMovementAnimation()
	end
end

function MovementShared.ScheduleDeferTask(self: SharedMovementEngine, time: number)
	if self.DeferredCancelTask then
		task.cancel(self.DeferredCancelTask)
	end

	self.DeferredCancelTask = task.delay(time, function()
		self.DeferredCancelTask = nil
		self:DeferTask()
	end)
end

function MovementShared.LockMovement(self: SharedMovementEngine, duration: number)
	self:DisableMovement()
	self:ScheduleDeferTask(duration)
end

function MovementShared.UnlockMovement(self: SharedMovementEngine)
	self:DeferTask()
end

function MovementShared.IsMovementEnabled(self: SharedMovementEngine): boolean
	return self.MovementEnabled and not (self.AllMovementDisabled == true)
end

function MovementShared.IsGrounded(self: SharedMovementEngine): boolean
	local humanoidState = self.Humanoid:GetState()
	if humanoidState == Enum.HumanoidStateType.Freefall
		or humanoidState == Enum.HumanoidStateType.Jumping
		or humanoidState == Enum.HumanoidStateType.FallingDown
	then
		return false
	end

	return self.Humanoid.FloorMaterial ~= Enum.Material.Air
end

return table.freeze(MovementShared)
