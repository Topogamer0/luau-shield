-- Safe (v0.2.0 review): a state machine whose work is wrapped in pcall, with the state reset after it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("x")
local state: { [Player]: string } = {}
-- direct UpdateAsync then reset
ReplicatedStorage.Remotes.Direct.OnServerEvent:Connect(function(player)
	if state[player] ~= "Idle" then
		return
	end
	state[player] = "Saving"
	store:UpdateAsync(tostring(player.UserId), function(old) return old end)
	state[player] = "Idle"
end)
-- same with pcall method idiom
ReplicatedStorage.Remotes.Pcall.OnServerEvent:Connect(function(player)
	if state[player] ~= "Idle" then
		return
	end
	state[player] = "Saving"
	pcall(store.UpdateAsync, store, tostring(player.UserId), function(old) return old end)
	state[player] = "Idle"
end)
