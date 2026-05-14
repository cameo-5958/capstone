--!strict

-- All Services to require thus far
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = ReplicatedStorage:WaitForChild("Services")

local ToLoad = {
	"Collision",
	"ItemDrop",
	"World",
	"Equipment",
	"Inventory",
	"Enemy",
	"Projectile",
	"Attack",
	"Weapon",
	"Player",
	"Item",
	"ItemLoadout",
	"Animation",
	"Shop",
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
	ensureRemoteEvent("Item", "ItemEndpoint")
	ensureRemoteEvent("ItemLoadout", "ItemLoadoutEndpoint")
	ensureRemoteEvent("Player", "PlayerEndpoint")
	ensureRemoteEvent("World", "WorldEndpoint")
	ensureRemoteEvent("Animation", "AnimationHandler")
	ensureRemoteEvent("Shop", "ShopEndpoint")
end

function Loader.load()
	ensureEarlyRemotes()

	local tasks = {}
	for _, Service in ipairs(ToLoad) do
		print(string.format("[ServerLoader] requiring service %s", Service))

		local serviceFolder = Services:FindFirstChild(Service)
		if not serviceFolder then
			warn(string.format("[ServerLoader] service folder %s missing, waiting up to 5 seconds", Service))
			serviceFolder = Services:WaitForChild(Service, 5)
		end

		if not serviceFolder then
			warn(string.format("[ServerLoader] service folder %s still missing after timeout", Service))
		else
			local serverScript = serviceFolder:FindFirstChild(Service .. "ServiceServer")
			if not serverScript then
				warn(string.format("[ServerLoader] server script for %s missing, waiting up to 5 seconds", Service))
				serverScript = serviceFolder:WaitForChild(Service .. "ServiceServer", 5)
			end

			if not serverScript then
				warn(string.format("[ServerLoader] server script for %s still missing after timeout", Service))
			else
				local success, result = pcall(function()
					Loader["Services"][Service] = require(serverScript) :: any
				end)

				if not success then
					warn(string.format("[ServerLoader] failed to require %s: %s", Service, tostring(result)))
				else
					if Loader["Services"][Service].init then
						table.insert(
							tasks,
							task.spawn(function()
								print(string.format("[ServerLoader] initializing service %s", Service))
								local initSuccess, initResult = pcall(function()
									Loader["Services"][Service].init()
								end)
								if not initSuccess then
									warn(
										string.format(
											"[ServerLoader] init failed for %s: %s",
											Service,
											tostring(initResult)
										)
									)
								end
							end)
						)
					end
				end
			end
		end
	end

	-- Wait for all inits to complete
	for _, taskThread in ipairs(tasks) do
		repeat
			task.wait()
		until taskThread and coroutine.status(taskThread) == "dead"
	end
end

-- Return Loaded
return Loader
