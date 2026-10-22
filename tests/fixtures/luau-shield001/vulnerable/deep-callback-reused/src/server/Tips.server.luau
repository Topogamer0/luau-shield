local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RewardService = require(ServerScriptService.Services.RewardService)

-- Vulnerable: the client chooses the amount of coins it receives.
ReplicatedStorage.Remotes.Tip.OnServerEvent:Connect(function(player, amount)
	RewardService.give(player, amount)
end)
