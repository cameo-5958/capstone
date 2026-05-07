--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryServiceServer = require(ReplicatedStorage.Services.Inventory.InventoryServiceServer)

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")
local SeededPlayers: { [Player]: boolean } = {}

local function collectWeaponPaths(root: Instance, currentPath: string?, paths: { string }): ()
	if root:FindFirstChild("Data") then
		if currentPath and currentPath ~= "" then
			table.insert(paths, currentPath)
		end
		return
	end

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("Folder") then
			local nextPath = if currentPath and currentPath ~= "" then currentPath .. "." .. child.Name else child.Name
			collectWeaponPaths(child, nextPath, paths)
		end
	end
end

local function getAllWeaponPaths(): { string }
	local paths = {}
	collectWeaponPaths(WeaponsDatabase, nil, paths)
	table.sort(paths)
	return paths
end

local function seedDebugInventory(player: Player): ()
	if SeededPlayers[player] then
		return
	end

	SeededPlayers[player] = true
	for _, weaponPath in ipairs(getAllWeaponPaths()) do
		InventoryServiceServer.AddWeaponFromPath(player, weaponPath)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		seedDebugInventory(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	SeededPlayers[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(function()
		seedDebugInventory(player)
	end)
end
