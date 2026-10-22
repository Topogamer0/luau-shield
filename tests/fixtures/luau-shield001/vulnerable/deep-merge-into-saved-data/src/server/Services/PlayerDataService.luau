local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local SettingsMigrations = require(ServerScriptService.Services.SettingsMigrations)

local store = DataStoreService:GetDataStore("PlayerData")
local PlayerDataService = {}

local function defaultsFor(player)
	return { Coins = 0, Gems = 0, MusicVolume = 0.5, Rebirths = 0 }
end

function PlayerDataService.mergeSettings(player, incoming)
	return SettingsMigrations.fromV1(defaultsFor(player), incoming)
end

function PlayerDataService.saveSettings(player, incoming)
	local data = PlayerDataService.mergeSettings(player, incoming)
	store:SetAsync("player_" .. player.UserId, data) -- expect: luau-shield001
	player.leaderstats.Coins.Value = data.Coins -- expect: luau-shield001
end

return PlayerDataService
