-- Safe (luau-shield v0.2.0 report, case 2): an admin chat command. Only
-- players that pass `Admins.isAdmin` reach the write, and the amount is a
-- number parsed from digits only (never NaN) and clamped.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Admins = require(ServerScriptService.Admins)
local data = {}

local function onCommand(sender, text)
	if not Admins.isAdmin(sender) then return end
	local amount = math.clamp(tonumber(string.match(text, "(%-?%d+)")) or 0, -1e9, 1e9)
	data[sender].Coins += amount
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(text) onCommand(player, text) end)
end)
