--!strict
-- Vulnerable: the settings menu saves to the DataStore on every click. An
-- exploiter fires the remote in a loop: DataStore requests are throttled for
-- the whole server, so other players' saves start failing.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local settingsStore = DataStoreService:GetDataStore("Settings")

ReplicatedStorage.Remotes.SaveSettings.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local settings = {
		music = player:GetAttribute("Music") == true,
		effects = player:GetAttribute("Effects") == true,
	}
	settingsStore:SetAsync(tostring(player.UserId), settings)
end)
