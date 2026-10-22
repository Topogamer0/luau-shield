--!strict
-- Safe: per-player cooldown with os.clock before the DataStore write.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local settingsStore = DataStoreService:GetDataStore("Settings")
local COOLDOWN = 10
local lastSave: { [Player]: number } = {}

ReplicatedStorage.Remotes.SaveSettings.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if lastSave[player] and now - lastSave[player] < COOLDOWN then
		return
	end
	lastSave[player] = now
	settingsStore:SetAsync(tostring(player.UserId), {
		music = player:GetAttribute("Music") == true,
	})
end)

Players.PlayerRemoving:Connect(function(player)
	lastSave[player] = nil
end)
