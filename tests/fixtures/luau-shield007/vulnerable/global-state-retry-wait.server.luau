-- Vulnerable (v0.2.0 review): the only wait is a retry backoff on failure.
-- Global state released right after the save; the only wait is the retry
-- backoff on failure. A client can fire back to back.
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
	for attempt = 1, 3 do
		local ok = pcall(store.UpdateAsync, store, "board", function(old)
			return old
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	boardState = "Idle"
end)
