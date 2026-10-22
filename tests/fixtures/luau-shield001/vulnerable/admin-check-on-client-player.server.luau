-- Vulnerable: the admin check tests a player chosen by the client, not the
-- sender. An exploiter passes the owner as `asAdmin` and sets any balance.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Admins = require(ServerScriptService.Admins)
local data = {}

ReplicatedStorage.Remotes.AdminSetCoins.OnServerEvent:Connect(function(player, asAdmin, coins)
	if not Admins.isAdmin(asAdmin) then
		return
	end
	data[player].Coins = coins -- expect: luau-shield001
end)
