local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shop = require(ServerScriptService.Shop)
local data = require(ServerScriptService.PlayerData)

ReplicatedStorage.Remotes.ClaimReward.OnServerEvent:Connect(function(player, amount)
	data[player].Coins += Shop.quote(amount) -- expect: luau-shield001
end)
