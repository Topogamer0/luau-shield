-- Vulnerable: the profile viewer reads a DataStore on every invoke, so a
-- client can burn the read budget of the whole server.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local statsStore = DataStoreService:GetDataStore("PlayerStats")
local GetMyStats = ReplicatedStorage.Remotes.GetMyStats :: RemoteFunction

GetMyStats.OnServerInvoke = function(player: Player) -- expect: luau-shield007
	local ok, stats = pcall(function()
		return statsStore:GetAsync(tostring(player.UserId))
	end)
	return if ok then stats else nil
end
