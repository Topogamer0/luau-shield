-- Vulnerable (v0.2.0 review): the only wait runs when the save fails; when saves succeed the shared state reopens at once.
-- Global leaderboard state closed during the save and reopened as soon as
-- it returns. The save is a direct `store:UpdateAsync` call; the only wait
-- is a back-off when the save returned nothing. When saves succeed, a
-- client fires back to back: one UpdateAsync per request, for the whole
-- server's DataStore budget.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Board")
local Submit = ReplicatedStorage.Remotes.SubmitScore
local boardState = "Idle"

Submit.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	if boardState ~= "Idle" then
		return
	end
	boardState = "Saving"
	local saved = store:UpdateAsync("board", function(old)
		old = old or {}
		old[tostring(player.UserId)] = true
		return old
	end)
	if not saved then
		task.wait(5) -- back off when the save failed
	end
	boardState = "Idle"
end)
