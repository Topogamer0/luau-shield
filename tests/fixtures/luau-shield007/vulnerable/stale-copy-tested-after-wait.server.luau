-- Vulnerable (v0.2.0 review): a copy of the state read before a wait is tested after it.
-- Same with task.wait: the local copy is read, the handler waits for the
-- countdown, then the stale copy is tested. Every request fired during the
-- wait passes.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Queue")
local Join = ReplicatedStorage.Remotes.Join
local state: { [Player]: string } = {}

Join.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local current = state[player]
	task.wait(1) -- short countdown before joining
	if current ~= "Lobby" then
		return
	end
	state[player] = "Queued"
	store:SetAsync(tostring(player.UserId), "Queued")
end)
