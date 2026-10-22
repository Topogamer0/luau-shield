-- Safe at the default threshold: the admin panel trusts the amount typed by
-- the admin. The write is only reachable after `Permissions:hasPermission`
-- succeeds for the sender, so luau-shield reports it as `info` ("admin
-- only"), which is hidden unless `--min-severity info` is used.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Permissions = require(ServerScriptService.Permissions)
local data = {}

ReplicatedStorage.Remotes.AdminSetCoins.OnServerEvent:Connect(function(player, target, coins)
	if not Permissions:hasPermission(player, "EditCoins") then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end
	data[target].Coins = coins
end)
