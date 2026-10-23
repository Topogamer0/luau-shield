-- Vulnerable (v0.2.0 review): changing a local copy does not change the state.
-- Leaving a match saves the player's stats. The handler copies the state
-- into a local and changes the local: `sessions[player].State` stays
-- "Playing", so every request passes the test and saves again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("Stats")
local sessions = {}

ReplicatedStorage.Remotes.LeaveMatch.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	local state = sessions[player].State
	if state ~= "Playing" then
		return
	end
	state = "Leaving"
	task.wait(1) -- let the leave animation play
	store:UpdateAsync("stats_" .. player.UserId, function(old)
		return old
	end)
end)
