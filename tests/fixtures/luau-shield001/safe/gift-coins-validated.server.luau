-- Safe: gifting coins to another player (twin of the vulnerable
-- stat-alias-findfirstchild entry). The amount is a number, not NaN, at least
-- 1, a whole number and at most what the sender owns, so negative, huge,
-- fractional and NaN amounts are all rejected before either stat changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GiftCoins = ReplicatedStorage.Remotes.GiftCoins

GiftCoins.OnServerEvent:Connect(function(player, targetName, amount)
	if typeof(targetName) ~= "string" or typeof(amount) ~= "number" then
		return
	end
	if amount ~= amount or amount < 1 or amount % 1 ~= 0 then
		return
	end
	local target = Players:FindFirstChild(targetName)
	if not target or target == player or not target:IsA("Player") then
		return
	end

	local coins = player.leaderstats:FindFirstChild("Coins")
	local targetCoins = target.leaderstats:FindFirstChild("Coins")
	if not coins or not targetCoins or amount > coins.Value then
		return
	end

	coins.Value -= amount
	targetCoins.Value += amount
end)
