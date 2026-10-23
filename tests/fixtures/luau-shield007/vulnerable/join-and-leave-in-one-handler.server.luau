-- Vulnerable (v0.2.0 review): the same handler reopens the state on another branch (join, leave, join...).
-- Matchmaking queue driven by ONE remote with an action argument. "join"
-- tests and changes the state (looks like a state machine), but "leave",
-- on the same remote, puts it back with no limit: a client alternates
-- Queue:FireServer("join") / Queue:FireServer("leave") and every "join"
-- does a MemoryStore/DataStore round trip.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local queueStore = DataStoreService:GetDataStore("Queue")
local QueueRemote = ReplicatedStorage.Remotes.Queue
local state: { [Player]: string } = {}

QueueRemote.OnServerEvent:Connect(function(player: Player, action: unknown) -- expect: luau-shield007
	if action == "join" then
		if state[player] ~= "Lobby" then
			return
		end
		state[player] = "Queued"
		queueStore:UpdateAsync("queue", function(list)
			list = list or {}
			table.insert(list, player.UserId)
			return list
		end)
	elseif action == "leave" then
		state[player] = "Lobby"
	end
end)
