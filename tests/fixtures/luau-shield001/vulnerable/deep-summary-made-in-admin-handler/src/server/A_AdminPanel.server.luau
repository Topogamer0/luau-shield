-- Vulnerable (v0.2.0 review): a return summary made inside an admin handler must not make another handler admin only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local Shop = require(ServerScriptService.Shop)
local data = require(ServerScriptService.PlayerData)

ReplicatedStorage.Remotes.AdminGrant.OnServerEvent:Connect(function(player, amount)
	if not Admins.isAdmin(player) then
		return
	end
	data[player].Coins += Shop.quote(amount)
end)
