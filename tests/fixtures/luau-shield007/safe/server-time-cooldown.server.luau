-- Safe: cooldown based on workspace:GetServerTimeNow(), stored per player.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local statsStore = DataStoreService:GetDataStore("PlayerStats")
local GetMyStats = ReplicatedStorage.Remotes.GetMyStats :: RemoteFunction
local nextAllowed: { [number]: number } = {}

GetMyStats.OnServerInvoke = function(player: Player)
	local now = workspace:GetServerTimeNow()
	if (nextAllowed[player.UserId] or 0) > now then
		return nil
	end
	nextAllowed[player.UserId] = now + 5
	return statsStore:GetAsync(tostring(player.UserId))
end
