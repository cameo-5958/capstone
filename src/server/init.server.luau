--!strict

-- Import the server loader
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerLoader = require(ReplicatedStorage.Services.Loader.ServerLoader)

-- Call the server loader's load method
ServerLoader.load()

-- Load a test entity
local SpawnBlock = Instance.new("Part")
SpawnBlock.Size = Vector3.new(10, 1, 10)
SpawnBlock.Position = Vector3.new(0, 15, 0)
SpawnBlock.Anchored = true
SpawnBlock.Transparency = 0.5
SpawnBlock.CanCollide = false
local EnemyServiceServer = ServerLoader.Services["Enemy"]
local MAX_SPAWN_LEVEL = 120
local LEVEL_PER_SPAWN = 5
local INITIAL_SPAWN_DELAY = 15
local SPAWN_DELAY_INCREMENT = 10
local ENEMY_ROTATION = { "Golem.Basalt", "Golem.Granite", "Golem.Runic" }

-- Spawn a few enemies :)
task.spawn(function()
	local spawnDelay = INITIAL_SPAWN_DELAY
	local rotationIndex = 1
	for level = LEVEL_PER_SPAWN, MAX_SPAWN_LEVEL, LEVEL_PER_SPAWN do
		local enemyPath = ENEMY_ROTATION[rotationIndex]
		EnemyServiceServer.Spawn(enemyPath, SpawnBlock, level)
		rotationIndex += 1
		if rotationIndex > #ENEMY_ROTATION then
			rotationIndex = 1
		end
		task.wait(spawnDelay)
		spawnDelay += SPAWN_DELAY_INCREMENT
	end
end)
