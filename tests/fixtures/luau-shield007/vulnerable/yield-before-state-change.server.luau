-- Vulnerable (v0.2.0 review): requests fired during the yield all pass the test.
-- The state is tested, then the handler yields for the leave animation,
-- and only then changes the state. Every request fired during those 2
-- seconds passes the test and saves.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Saves")
local LeaveGame = ReplicatedStorage.Remotes.LeaveGame
local state = {}

local function save(old)
	return old
end

LeaveGame.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	if state[player] ~= "Playing" then
		return
	end
	task.wait(2) -- leave animation
	state[player] = "Menu"
	store:UpdateAsync(player.UserId, save)
end)
