--!strict

local PhysicsService = game:GetService("PhysicsService")

local CollisionServiceServer = {}

local REGISTERED = false

local function ensureGroup(name: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
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
	REGISTERED = true
end

function CollisionServiceServer.AssignModel(model: Model, groupName: string)
	CollisionServiceServer.init()
	applyGroupRecursive(model, groupName)
end

return table.freeze(CollisionServiceServer)
