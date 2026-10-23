-- Vulnerable (v0.2.0 review): a Chatted listener connected after an admin check and again without one.
-- Admins get chat commands when they join; a second handler (added later for
-- a "commands for everyone in private servers" feature) connects the same
-- listener for every player in a private server, which anyone can buy.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
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
	if Admins.isAdmin(player) then
		bindCommands(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	if game.PrivateServerId ~= "" then
		bindCommands(player)
	end
end)
