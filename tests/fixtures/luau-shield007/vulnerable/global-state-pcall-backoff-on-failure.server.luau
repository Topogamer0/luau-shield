-- Vulnerable (v0.2.0 review): the save is wrapped in pcall and the back-off only runs on failure.
-- Same shape as the fixture global-state-retry-wait, written without a loop:
-- the wait only runs when the save fails.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Board")
local Submit = ReplicatedStorage.Remotes.SubmitScore
local boardState = "Idle"

Submit.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	if boardState ~= "Idle" then
		return
	end
	boardState = "Saving"
	local ok = pcall(store.UpdateAsync, store, "board", function(old)
		return old
	end)
	if not ok then
		task.wait(5)
	end
	boardState = "Idle"
end)
