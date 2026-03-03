--!strict

-- Import the server loader
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerLoader = require(ReplicatedStorage.Services.Loader.ServerLoader)

-- Call the server loader's load method
ServerLoader.load()

-- Load a test entity
local SpawnBlock = workspace:WaitForChild("SpawnPoint")
local EnemyServiceServer = ServerLoader.Services["Enemy"]

EnemyServiceServer.Spawn("Goblins.Goblin", SpawnBlock)
