--!strict

-- Animation service for handling animations
-- Get the API

local API = script.Parent:WaitForChild("AnimationHandler") :: RemoteEvent
local EntitiesFolder = workspace:WaitForChild("EntitiesFolder")
local Players = game:GetService("Players")

local AnimationServiceClient = {}

local LocalPlayer = Players.LocalPlayer

-- GetTrack
local function GetAnimationTrack(animator: Animator, animId: string): AnimationTrack?
    -- Grab loaded track if possible
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track.Animation.AnimationId == animId then
            -- Return this track
            return track
        end
    end

    return
end

-- LoadTrack
local function LoadTrack(animator: Animator, animId: string): AnimationTrack
    -- Create a new animation, load and play
    local anim = Instance.new("Animation")
    anim.AnimationId = animId

    return animator:LoadAnimation(anim)
end

-- Animating
local function Animate(character: Model, animId: string)
    -- Ensure the character has an animator already
    local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
    local animator: Animator = humanoid:FindFirstChild("Animator") :: Animator or Instance.new("Animator")

    animator.Parent = humanoid

    -- Confirm the animation isn't loaded
    local track = GetAnimationTrack(animator, animId) or LoadTrack(animator, animId)
    
    -- Play the animation
    track:Play()
end

-- Stop animation
local function Stop(character: Model, animId: string)
    local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
    local animator = humanoid:FindFirstChild("Animator") :: Animator

    if not animator then
        error("Attempted to stop animation of character without animator")
    end

    local track = GetAnimationTrack(animator, animId)

    -- No track: tried to stop something without a track
    if not track then
        error("Track is not playing")
    end
    
    -- Stop it
    track:Stop()
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
local function GetPlayer(player: Player): Model
    -- Grab the character of the player
    local character = player.Character or player.CharacterAdded:Wait()

    -- Animate the found model
    return character --Animate(character, animId)
end

-- Handle animation generally
API.OnClientEvent:Connect(function(identifier: Player | string, manageType: string, animId: string, status: string)
    local model: Model
    if manageType == "UUID" then
        model = GetEntity(identifier :: string)
    elseif manageType == "Player" then
        model = GetPlayer(identifier :: Player)
    end

    -- stop the animation
    if status == "Stop" then
        Stop(model, animId)
    else
        -- Play the animation
        Animate(model, animId)
    end
end)

-- Animate myself
function AnimationServiceClient.Animate(animId: string)
    -- Play my own animation

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Animate(character, animId)

    -- Call API with my animId
    API:FireServer(animId, "Start")
end

function AnimationServiceClient.StopAnimation(animId: string)
    -- Stop your own character
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Stop(character, animId)

    -- Call API with my animId
    API:FireServer(animId, "Stop")
end

return AnimationServiceClient