--!strict

-- Create the animation API
local API = script.Parent:WaitForChild("AnimationHandler") :: RemoteEvent

-- Requires
local Players = game:GetService("Players")
local AnimationService = {}
type AnimationId = string | { string }

-- Public API for animating non-players
function AnimationService.Animate(uuid: string, animID: AnimationId)
	-- Broadcast, to all players, a request to
	-- animate a NON-PLAYER object

	API:FireAllClients(uuid, "UUID", animID, "Start")
end

-- Public API for stopping non-players
function AnimationService.Stop(uuid: string, animID: AnimationId)
	-- Broadcast, to all players, a request to
	-- animate a NON-PLAYER object

	API:FireAllClients(uuid, "UUID", animID, "Stop")
end

local function BroadcastPlayerAnimation(player: Player, animID: AnimationId, status: string, includeSelf: boolean)
	for _, ply in ipairs(Players:GetPlayers()) do
		if includeSelf or ply ~= player then
			API:FireClient(ply, player, "Player", animID, status)
		end
	end
end

function AnimationService.PlayPlayer(player: Player, animID: AnimationId)
	BroadcastPlayerAnimation(player, animID, "Start", true)
end

function AnimationService.PlayPlayerOnce(player: Player, animID: AnimationId)
	BroadcastPlayerAnimation(player, animID, "StartOnce", true)
end

function AnimationService.StopPlayer(player: Player, animID: AnimationId)
	BroadcastPlayerAnimation(player, animID, "Stop", true)
end

-- Public API for animating players
local function AnimatePlayer(player: Player, animID: AnimationId, status: string)
	BroadcastPlayerAnimation(player, animID, status, false)
end

API.OnServerEvent:Connect(AnimatePlayer)

return table.freeze(AnimationService)
