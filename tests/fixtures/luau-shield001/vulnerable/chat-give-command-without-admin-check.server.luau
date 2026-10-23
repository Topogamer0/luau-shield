-- Vulnerable: the same chat command with the admin check forgotten. Any
-- player can type a number (or "nan", "inf") and get that many coins.
local Players = game:GetService("Players")

local data = {}

local function onCommand(sender, text)
	data[sender].Coins += tonumber(text) or 0 -- expect: luau-shield001
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(text) onCommand(player, text) end)
end)
