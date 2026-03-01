--!strict

-- All modules to require thus far
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local ToLoad = {
	"Enemy",
}

-- Load all modules in ToLoad and initialize them
local Loaded = {}
for _, module in ipairs(ToLoad) do
	Loaded[module] = require(Modules:WaitForChild(module)[module .. "ModuleServer"]) :: any

	if Loaded[module].init then
		Loaded[module].init()
	end
end

-- Return Loaded
return table.freeze(Loaded)
