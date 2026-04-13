--!strict

local PhysicsService = game:GetService("PhysicsService")

local CollisionServiceServer = {}

local REGISTERED = false
local BoundModels = setmetatable({}, { __mode = "k" }) :: { [Model]: RBXScriptConnection }

local function ensureGroup(name: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function setGroupsCollidable(groupA: string, groupB: string, canCollide: boolean)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(groupA, groupB, canCollide)
	end)
end

local function applyGroupRecursive(instance: Instance, groupName: string)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = groupName
	end

	for _, child in ipairs(instance:GetChildren()) do
		applyGroupRecursive(child, groupName)
	end
end

function CollisionServiceServer.init()
	if REGISTERED then
		return
	end

	ensureGroup("Enemy")
	ensureGroup("Player")
	setGroupsCollidable("Enemy", "Enemy", false)
	setGroupsCollidable("Enemy", "Player", false)
	REGISTERED = true
end

function CollisionServiceServer.AssignModel(model: Model, groupName: string)
	CollisionServiceServer.init()
	applyGroupRecursive(model, groupName)

	local existing = BoundModels[model]
	if existing then
		existing:Disconnect()
	end

	BoundModels[model] = model.DescendantAdded:Connect(function(descendant)
		applyGroupRecursive(descendant, groupName)
	end)
end

return table.freeze(CollisionServiceServer)
