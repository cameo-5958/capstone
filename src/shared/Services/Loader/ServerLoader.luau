--!strict

-- All Services to require thus far
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = ReplicatedStorage:WaitForChild("Services")

local ToLoad = {
	"Enemy",
	"Player",
}

-- Load all Services in ToLoad and initialize them
local Loader = { ["Services"] = {} }

function Loader.load()
	for _, Service in ipairs(ToLoad) do
		Loader["Services"][Service] = require(Services:WaitForChild(Service)[Service .. "ServiceServer"]) :: any

		if Loader["Services"][Service].init then
			Loader["Services"][Service].init()
		end
	end
end

-- Return Loaded
return Loader
