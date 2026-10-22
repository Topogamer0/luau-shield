-- Vulnerable (v0.2.0 review): the same Chatted listener is connected for admins and for VIPs; VIP messages are not admin messages.
-- Chat commands: admins get every command; players who own the VIP gamepass
-- get the same listener (the command table decides). Both paths connect the
-- same `player.Chatted` listener from `bindCommands`.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local VIP_PASS = 123456
local data = {}

local function bindCommands(player)
	player.Chatted:Connect(function(message)
		local args = string.split(message, " ")
		if args[1] == ";coins" then
			data[player].Coins = tonumber(args[2]) -- expect: luau-shield001
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	data[player] = { Coins = 0 }
	if Admins.isAdmin(player) then
		bindCommands(player)
		return
	end
	if MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS) then
		bindCommands(player)
	end
end)
