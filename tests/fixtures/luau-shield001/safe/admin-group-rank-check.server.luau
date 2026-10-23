-- Safe (v0.2.0 review): only high group ranks pass `GetRankInGroup` (info).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Admins = require(ServerScriptService.Admins)
local data = {}
local GROUP_ID = 1234567
ReplicatedStorage.Remotes.AdminSetCoins.OnServerEvent:Connect(function(player, userId, coins)
	if player:GetRankInGroup(GROUP_ID) < 250 then
		return
	end
	data[userId].Coins = coins
end)
