-- Safe (v0.2.0 review): only the game creator passes `player.UserId == game.CreatorId` (info).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Admins = require(ServerScriptService.Admins)
local data = {}
ReplicatedStorage.Remotes.AdminSetCoins.OnServerEvent:Connect(function(player, userId, coins)
	if player.UserId ~= game.CreatorId then
		return
	end
	data[userId].Coins = coins
end)
