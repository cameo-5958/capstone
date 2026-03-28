--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Classes.Modifier.Signal)

local API = script.Parent:WaitForChild("PlayerEndpoint") :: RemoteEvent

local PlayerServiceClient = {}

local Stats: { [string]: number } = {}
local StatChanged = Signal.new()

local function SyncStat(statName: string, value: number)
	local oldValue = Stats[statName]
	if oldValue == value then
		return
	end

	Stats[statName] = value
	StatChanged:Fire(statName, value, oldValue)
end

local function SyncStats(snapshot: { [string]: number })
	for statName, value in pairs(snapshot) do
		SyncStat(statName, value)
	end
end

API.OnClientEvent:Connect(function(action: string, payload: { [string]: any }?)
	if action == "SyncStats" and payload and payload.Stats then
		SyncStats(payload.Stats)
	elseif action == "SyncStat" and payload and payload.Stat and payload.Value ~= nil then
		SyncStat(payload.Stat, payload.Value)
	end
end)

task.defer(function()
	API:FireServer("RequestSnapshot")
end)

function PlayerServiceClient.GetStat(statName: string): number?
	return Stats[statName]
end

function PlayerServiceClient.GetStats(): { [string]: number }
	return table.clone(Stats)
end

function PlayerServiceClient.GetStatChangedSignal()
	return StatChanged
end

function PlayerServiceClient.RequestDashIFrames(): ()
	API:FireServer("RequestDashIFrames")
end

return table.freeze(PlayerServiceClient)
