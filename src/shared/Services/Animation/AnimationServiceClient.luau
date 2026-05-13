--!strict

-- Animation service for handling animations
-- Get the API

local API = script.Parent:WaitForChild("AnimationHandler") :: RemoteEvent
local EntitiesFolder = workspace:WaitForChild("EntitiesFolder")
local Players = game:GetService("Players")

local AnimationServiceClient = {}

local LocalPlayer = Players.LocalPlayer
type AnimationId = string | { string }
local LoadedTracks = setmetatable({}, { __mode = "k" }) :: { [Animator]: { [string]: AnimationTrack } }

local function GetTrackCache(animator: Animator): { [string]: AnimationTrack }
	local cache = LoadedTracks[animator]
	if cache then
		return cache
	end

	cache = {}
	LoadedTracks[animator] = cache
	return cache
end

local function ResolveAnimationId(animId: AnimationId): string?
	if type(animId) == "string" then
		if animId == "" then
			return nil
		end

		return animId
	end

	local count = #animId
	if count == 0 then
		return nil
	end

	local chosen = animId[math.random(1, count)]
	if type(chosen) ~= "string" or chosen == "" then
		return nil
	end

	return chosen
end

local function ResolveAnimationIds(animId: AnimationId): { string }
	if type(animId) == "string" then
		if animId == "" then
			return {}
		end

		return { animId }
	end

	local resolved = {}
	for _, value in ipairs(animId) do
		if type(value) == "string" and value ~= "" then
			table.insert(resolved, value)
		end
	end

	return resolved
end

-- GetTrack
local function GetAnimationTrack(animator: Animator, animId: string): AnimationTrack?
	local cachedTrack = GetTrackCache(animator)[animId]
	if cachedTrack then
		return cachedTrack
	end

	-- Grab loaded track if possible
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation.AnimationId == animId then
			-- Return this track
			GetTrackCache(animator)[animId] = track
			return track
		end
	end

	return
end

-- LoadTrack
local function LoadTrack(animator: Animator, animId: string): AnimationTrack
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	GetTrackCache(animator)[animId] = track
	return track
end

local function GetAnimator(character: Model): Animator?
	local animationController = character:FindFirstChild("AnimationController")
	if animationController and animationController:IsA("AnimationController") then
		local existingControllerAnimator = animationController:FindFirstChild("Animator")
		if existingControllerAnimator and existingControllerAnimator:IsA("Animator") then
			return existingControllerAnimator
		end
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid:IsA("Humanoid") then
		local existingHumanoidAnimator = humanoid:FindFirstChild("Animator")
		if existingHumanoidAnimator and existingHumanoidAnimator:IsA("Animator") then
			return existingHumanoidAnimator
		end
	end

	local existingAnimator = character:FindFirstChildWhichIsA("Animator", true)
	if existingAnimator and existingAnimator:IsA("Animator") then
		return existingAnimator
	end

	if humanoid and humanoid:IsA("Humanoid") then
		local animator = humanoid:FindFirstChild("Animator")
		if animator and animator:IsA("Animator") then
			return animator
		end

		animator = Instance.new("Animator")
		animator.Parent = humanoid
		return animator
	end

	if animationController and animationController:IsA("AnimationController") then
		local animator = animationController:FindFirstChild("Animator")
		if animator and animator:IsA("Animator") then
			return animator
		end

		animator = Instance.new("Animator")
		animator.Parent = animationController
		return animator
	end

	return nil
end

local function EnsureAnimationTrack(character: Model, animId: string): AnimationTrack?
	local animator = GetAnimator(character)
	if not animator then
		return nil
	end

	return GetAnimationTrack(animator, animId) or LoadTrack(animator, animId)
end

local function PreloadAnimations(character: Model, animIds: { string })
	for _, animId in ipairs(animIds) do
		if animId ~= "" then
			EnsureAnimationTrack(character, animId)
		end
	end
end

-- Animating
local function Animate(character: Model, animId: AnimationId, playOnce: boolean?)
	local resolvedAnimId = ResolveAnimationId(animId)
	if not resolvedAnimId then
		return
	end

	local track = EnsureAnimationTrack(character, resolvedAnimId)
	if not track then
		return
	end

	if playOnce then
		track.Looped = false
		track.TimePosition = 0
	else
		if track.IsPlaying then
			return
		end
	end

	-- Play the animation
	track:Play()
end

-- Stop animation
local function Stop(character: Model, animId: AnimationId)
	local resolvedAnimIds = ResolveAnimationIds(animId)
	if #resolvedAnimIds == 0 then
		return
	end

	local animator = GetAnimator(character)
	if not animator then
		error("Attempted to stop animation of character without animator")
	end

	for _, resolvedAnimId in ipairs(resolvedAnimIds) do
		local track = GetAnimationTrack(animator, resolvedAnimId)
		if track then
			track:Stop()
		end
	end
end

-- Handle animation from a ENTITY
local function GetEntity(uuid: string): Model
	-- Get the entity from the folder
	local entity = EntitiesFolder:FindFirstChild(uuid)

	if not entity then
		error("Attempted to animate entity with uuid " .. uuid .. ": not found")
	end

	-- Animate the found model
	return entity --Animate(entity, animId)
end

-- Handle animation from a PLAYER
local function GetPlayer(player: Player): Model?
	-- Grab the character of the player
	local character = player.Character
	if not character or character.Parent == nil then
		return nil
	end

	-- Animate the found model
	return character --Animate(character, animId)
end

-- Handle animation generally
API.OnClientEvent:Connect(function(identifier: Player | string, manageType: string, animId: AnimationId, status: string)
	local model: Model?
	if manageType == "UUID" then
		model = GetEntity(identifier :: string)
	elseif manageType == "Player" then
		model = GetPlayer(identifier :: Player)
	end

	if not model then
		return
	end

	-- stop the animation
	if status == "Stop" then
		Stop(model, animId)
	elseif status == "StartOnce" then
		Animate(model, animId, true)
	else
		-- Play the animation
		Animate(model, animId)
	end
end)

-- Animate myself
function AnimationServiceClient.Animate(animId: AnimationId)
	-- Play my own animation

	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Animate(character, animId)

	-- Call API with my animId
	API:FireServer(animId, "Start")
end

function AnimationServiceClient.PreloadLocalAnimations(animIds: { string })
	local character = LocalPlayer.Character
	if not character or character.Parent == nil then
		return
	end

	PreloadAnimations(character, animIds)
end

function AnimationServiceClient.StopAnimation(animId: AnimationId)
	-- Stop your own character
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	Stop(character, animId)

	-- Call API with my animId
	API:FireServer(animId, "Stop")
end

function AnimationServiceClient.StopLocalAnimations(animIds: { string })
	local character = LocalPlayer.Character
	if not character or character.Parent == nil then
		return
	end

	for _, animId in ipairs(animIds) do
		if animId ~= "" then
			Stop(character, animId)
		end
	end
end

function AnimationServiceClient.IsLocalAnimationPlaying(animId: string): boolean
	if animId == "" then
		return false
	end

	local character = LocalPlayer.Character
	if not character or character.Parent == nil then
		return false
	end

	local animator = GetAnimator(character)
	if not animator then
		return false
	end

	local track = GetAnimationTrack(animator, animId)
	return track ~= nil and track.IsPlaying
end

function AnimationServiceClient.IsAnyLocalAnimationPlaying(animIds: { string }): boolean
	for _, animId in ipairs(animIds) do
		if AnimationServiceClient.IsLocalAnimationPlaying(animId) then
			return true
		end
	end

	return false
end

return AnimationServiceClient
