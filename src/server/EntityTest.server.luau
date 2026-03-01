--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyModuleServer = require(ReplicatedStorage.Modules.Enemy.EnemyModuleServer)

local SpawnBlock = workspace:WaitForChild("SpawnPoint")

EnemyModuleServer.Spawn("Goblins.Goblin", SpawnBlock)
