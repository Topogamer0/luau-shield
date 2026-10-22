-- Vulnerable (v0.2.0 review): a state flipped on both branches limits nothing.
-- Toggle written with string states: every request saves.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local store = DataStoreService:GetDataStore("Settings")
local ToggleMode = ReplicatedStorage.Remotes.ToggleMode
local mode = {}

ToggleMode.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	if mode[player] == "On" then
		mode[player] = "Off"
	else
		mode[player] = "On"
	end
	pcall(store.SetAsync, store, tostring(player.UserId), mode[player])
end)
