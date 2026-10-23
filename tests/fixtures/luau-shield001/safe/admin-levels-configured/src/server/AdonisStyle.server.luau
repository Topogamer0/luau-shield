-- Safe (v0.2.0 review): numeric admin levels from functions declared in `[guards] functions` (info).
-- Adonis-style checks: `Admin.CheckAdmin(player)` and numeric levels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Admin = require(ServerScriptService.AdminRanks)
local data = {}

ReplicatedStorage.Remotes.AdonisSetCoins.OnServerEvent:Connect(function(player, targetName, amount)
	if not Admin.CheckAdmin(player) then
		return
	end
	local target = Players:FindFirstChild(targetName)
	if target then
		data[target].Coins = amount
	end
end)

ReplicatedStorage.Remotes.AdonisSetGems.OnServerEvent:Connect(function(player, targetName, amount)
	if Admin.GetLevel(player) >= 300 then
		local target = Players:FindFirstChild(targetName)
		if target then
			data[target].Gems = amount
		end
	end
end)
