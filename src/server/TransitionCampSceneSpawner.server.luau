--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local services = ReplicatedStorage:WaitForChild("Services")
local world = services:WaitForChild("World")
local prefabs = world:WaitForChild("Prefabs")
local biomes = prefabs:WaitForChild("Biomes")
local shared = biomes:WaitForChild("Shared")

local TransitionCampScene = require(shared:WaitForChild("TransitionCampScene"))

local STAGING_FOLDER_NAME = "PrefabStaging"
local STAGING_MODEL_NAME = "TransitionCampScene"
local STAGING_POSITION = Vector3.new(0, 260, 0)

local function ensureStagingFolder(): Folder
	local existing = Workspace:FindFirstChild(STAGING_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = STAGING_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function spawnTransitionCampScene()
	local stagingFolder = ensureStagingFolder()
	local existingScene = stagingFolder:FindFirstChild(STAGING_MODEL_NAME)
	if existingScene then
		existingScene:Destroy()
	end

	local sceneModel = TransitionCampScene.Build(stagingFolder, {
		Position = STAGING_POSITION,
		TileSize = 6,
		SurfaceY = STAGING_POSITION.Y,
		Biome = "PineHighlands",
		Seed = 0,
		NameSuffix = "Staging",
	})
	sceneModel.Name = STAGING_MODEL_NAME
	sceneModel:SetAttribute("PrefabStaging", true)
end

spawnTransitionCampScene()
