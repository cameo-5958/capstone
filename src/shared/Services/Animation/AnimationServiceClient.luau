--!strict

-- Animation service for handling animations
-- Get the API

local API = script.Parent:WaitForChild("AnimationHandler") :: RemoteEvent
local EntitiesFolder = workspace:WaitForChild("EntitiesFolder")
local Players = game:GetService("Players")

local AnimationServiceClient = {}

local LocalPlayer = Players.LocalPlayer

-- Animating
local function Animate(character: Model, animId: string)
    -- Ensure the character has an animator already
    local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
    local animator: Animator = humanoid:FindFirstChild("Animator") :: Animator or Instance.new("Animator")

    animator.Parent = humanoid

    -- Confirm the animation isn't loaded
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track.Animation.AnimationId == animId then
            -- Just play this track
            track:Play()

            return
        end
    end

    -- Load the animation and play
    local anim = Instance.new("Animation")
    anim.AnimationId = animId
    local track = animator:LoadAnimation(anim)

    -- Play the animation
    track:Play()
end

-- Handle animation from a ENTITY
local function AnimateEntity(uuid: string, animId: string)
    -- Get the entity from the folder
    local entity = EntitiesFolder:FindFirstChild(uuid)

    if not entity then
        error("Attempted to animate entity with uuid " .. uuid .. ": not found")
        return 
    end

    -- Animate the found model
    Animate(entity, animId)
end

-- Handle animation from a PLAYER
local function AnimatePlayer(player: Player, animId: string)
    -- Grab the character of the player
    local character = player.Character or player.CharacterAdded:Wait()

    -- Animate the found model
    Animate(character, animId)
end

-- Handle animation generally
API.OnClientEvent:Connect(function(identifier: Player | string, manageType: string, animId: string)
    if manageType == "uuid" then
        AnimateEntity(identifier :: string, animId)
    elseif manageType == "Player" then
        AnimatePlayer(identifier :: Player, animId)
    end
end)

-- Animate myself
function AnimationServiceClient.Animate(animId: string)
    -- Play my own animation

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    Animate(character, animId)

    -- Call API with my animId
    API:FireServer(animId)
end

return AnimationServiceClient