-- Vulnerable (v0.2.0 review): a yield on the right of `and`, between the test and the change.
-- Join the queue: the state is tested, then the handler may YIELD
-- (x and task.wait(2)), then the state is changed. Every Join request fired while the
-- first one waits passes the test: each does the DataStore write.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local queueStore = DataStoreService:GetDataStore("Queue")
local Join = ReplicatedStorage.Remotes.Join
local state: { [Player]: string } = {}

Join.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	if state[player] ~= "Lobby" then
		return
	end
	local _ = player.Character == nil and task.wait(2)
	state[player] = "Queued"
	queueStore:SetAsync(tostring(player.UserId), "Queued")
end)
