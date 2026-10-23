-- Vulnerable (v0.2.0 review): `BindableFunction:Invoke()` yields between the test and the change.
-- Join the queue: the state is tested, then the handler YIELDS
-- (BindableFunction:Invoke(), whose handler loads data), then the state is changed. Every Join request fired while the
-- first one waits passes the test: each does the DataStore write.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local queueStore = DataStoreService:GetDataStore("Queue")
local Join = ReplicatedStorage.Remotes.Join
local GetRating = ServerStorage.Functions.GetRating :: BindableFunction
local state: { [Player]: string } = {}

Join.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	if state[player] ~= "Lobby" then
		return
	end
	local rating = GetRating:Invoke(player)
	if not rating then
		return
	end
	state[player] = "Queued"
	queueStore:SetAsync(tostring(player.UserId), "Queued")
end)
