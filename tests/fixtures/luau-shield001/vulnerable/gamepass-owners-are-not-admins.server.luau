-- Vulnerable (v0.2.0 review): a table of game pass owners is not a permission list.
-- Cache of gamepass ownership: any player can buy the pass.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIP_PASS = 123456
local vipOwners = {}
local PassOwners = {}
local data = {}

Players.PlayerAdded:Connect(function(player)
	data[player] = { Coins = 0 }
	if MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_PASS) then
		vipOwners[player.UserId] = true
		table.insert(PassOwners, player.UserId)
	end
end)

ReplicatedStorage.Remotes.VipReward.OnServerEvent:Connect(function(player, amount)
	if not vipOwners[player.UserId] then
		return
	end
	data[player].Coins += amount -- expect: luau-shield001
end)

ReplicatedStorage.Remotes.VipReward2.OnServerEvent:Connect(function(player, amount)
	if not table.find(PassOwners, player.UserId) then
		return
	end
	data[player].Coins += amount -- expect: luau-shield001
end)
