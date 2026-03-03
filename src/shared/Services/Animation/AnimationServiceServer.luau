--!strict

-- Create the animation API
local API = Instance.new("RemoteEvent")
API.Parent = script.Parent
API.Name = "AnimationHandler"

-- Requires
local Players = game:GetService("Players")
local AnimationService = {}

-- Public API for animating non-players
function AnimationService.Animate(uuid: string, animID: string)
    -- Broadcast, to all players, a request to
    -- animate a NON-PLAYER object

    API:FireAllClients(uuid, "UUID", animID, "Start")
end

-- Public API for stopping non-players
function AnimationService.Stop(uuid: string, animID: string)
    -- Broadcast, to all players, a request to
    -- animate a NON-PLAYER object

    API:FireAllClients(uuid, "UUID", animID, "Stop")
end

-- Public API for animating players
local function AnimatePlayer(player: Player, animID: string, status: string)
    for _, ply in ipairs(Players:GetPlayers()) do
        -- Confirm it ISN'T the current player 
        -- (as they're already playing the animation)
        -- locally

        if ply ~= player then
            API:FireClient(ply, player, "Player", animID, status)
        end
    end
end

API.OnServerEvent:Connect(AnimatePlayer)

return table.freeze(AnimationService)