-- Safe (v0.2.0 review): only listed admin ids pass `table.find(ADMIN_IDS, player.UserId)` (info).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Admins = require(ServerScriptService.Admins)
local data = {}
local ADMIN_IDS = { 12345678, 87654321 }
ReplicatedStorage.Remotes.AdminSetCoins.OnServerEvent:Connect(function(player, userId, coins)
	if not table.find(ADMIN_IDS, player.UserId) then
		return
	end
	data[userId].Coins = coins
end)
