--!strict

-- Import the server loader
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerLoader = require(ReplicatedStorage.Services.Loader.ServerLoader)

-- Call the server loader's load method
ServerLoader.load()

-- Load a test entity
local SpawnBlock = workspace:WaitForChild("SpawnPoint")
local EnemyServiceServer = ServerLoader.Services["Enemy"]

-- Spawn a few enemies :)
task.spawn(function()
	for _ = 1, 5 do
		EnemyServiceServer.Spawn("Tests.Sword", SpawnBlock)
		task.wait(10)
	end
end)
