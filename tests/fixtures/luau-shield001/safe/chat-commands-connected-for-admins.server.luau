-- Safe (v0.2.0 review): the Chatted listener is only connected for admins; findings are admin-only (info).
-- Admin chat commands: the Chatted listener is only connected for admins.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local data = {}

Players.PlayerAdded:Connect(function(player)
	if not Admins.isAdmin(player) then
		return
	end
	player.Chatted:Connect(function(message)
		local userId, amount = message:match("^/setcoins (%d+) (%d+)$")
		if userId then
			data[tonumber(userId)].Coins = tonumber(amount)
		end
	end)
end)
