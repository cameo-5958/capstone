--!strict

-- All Services to require thus far
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = ReplicatedStorage:WaitForChild("Services")

local ToLoad = {
	"Collision",
	"World",
	"Equipment",
	"Inventory",
	"Enemy",
	"Projectile",
	"Attack",
	"Weapon",
	"Player",
	"Item",
	"ItemTool",
}

-- Load all Services in ToLoad and initialize them
local Loader = { ["Services"] = {} }

local function ensureRemoteEvent(serviceName: string, remoteName: string)
	local serviceFolder = Services:FindFirstChild(serviceName)
	if not serviceFolder then
		return
	end

	local existing = serviceFolder:FindFirstChild(remoteName)
	if existing and existing:IsA("RemoteEvent") then
		return
	end

	if existing then
		existing:Destroy()
	end

	local endpoint = Instance.new("RemoteEvent")
	endpoint.Name = remoteName
	endpoint.Parent = serviceFolder
end

local function ensureEarlyRemotes()
	-- Create latency-sensitive remotes before heavy service initialization (for example world generation).
	ensureRemoteEvent("Attack", "AttackEndpoint")
	ensureRemoteEvent("Projectile", "ProjectileEndpoint")
end

function Loader.load()
	ensureEarlyRemotes()

	for _, Service in ipairs(ToLoad) do
		Loader["Services"][Service] = require(Services:WaitForChild(Service)[Service .. "ServiceServer"]) :: any

		if Loader["Services"][Service].init then
			Loader["Services"][Service].init()
		end
	end
end

-- Return Loaded
return Loader
