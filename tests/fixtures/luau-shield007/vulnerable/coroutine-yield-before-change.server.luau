-- Vulnerable (v0.2.0 review): `coroutine.yield()` between the test and the change.
-- Join the queue: the state is tested, then the handler YIELDS
-- (coroutine.yield()), then the state is changed. Every Join request fired while the
-- first one waits passes the test: each does the DataStore write.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local queueStore = DataStoreService:GetDataStore("Queue")
local Join = ReplicatedStorage.Remotes.Join
local Confirm = ReplicatedStorage.Remotes.Confirm :: RemoteFunction
local MatchReady = ReplicatedStorage.Events.MatchReady :: BindableEvent
local state: { [Player]: string } = {}

Join.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	if state[player] ~= "Lobby" then
		return
	end
	coroutine.yield()
	state[player] = "Queued"
	queueStore:SetAsync(tostring(player.UserId), "Queued")
end)
