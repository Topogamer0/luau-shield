-- Vulnerable (v0.2.0 review): a Chatted listener on another player gets that player's messages, not the admin's.
-- An admin starts "watching" a player: the target's chat messages are relayed
-- to the admin and saved. The Chatted listener runs for the TARGET's
-- messages (any player), not for the admin's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local Admins = require(ServerScriptService.Admins)
local Logs = DataStoreService:GetDataStore("ChatLogs")
local data = {}

ReplicatedStorage.Remotes.WatchPlayer.OnServerEvent:Connect(function(admin, targetUserId)
	if not Admins.isAdmin(admin) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		return
	end
	target.Chatted:Connect(function(message)
		local args = string.split(message, " ")
		if args[1] == "!bet" then
			data[target].Coins -= tonumber(args[2]) -- expect: luau-shield001
		end
		Logs:SetAsync(message, admin.UserId) -- expect: luau-shield001
	end)
end)

Players.PlayerAdded:Connect(function(player)
	if not Admins.isAdmin(player) then
		return
	end
	-- Admin joined: relay everybody's chat bets to the admin console.
	for _, other in Players:GetPlayers() do
		other.Chatted:Connect(function(message)
			local args = string.split(message, " ")
			if args[1] == "!bet" then
				data[other].Coins -= tonumber(args[2]) -- expect: luau-shield001
			end
		end)
	end
end)
