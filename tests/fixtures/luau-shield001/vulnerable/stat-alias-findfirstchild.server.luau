-- Vulnerable: gifting coins to another player. The stat objects are reached
-- through local aliases obtained with FindFirstChild. The server checks the
-- type and that the sender has "enough" coins, but there is no lower bound.
--
-- Exploit: fire GiftCoins with (victimName, -50000). `-50000 > coins.Value`
-- is false, so the guard passes: the sender gains 50000 coins and the victim
-- loses them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GiftCoins = ReplicatedStorage.Remotes.GiftCoins

GiftCoins.OnServerEvent:Connect(function(player, targetName, amount)
	if typeof(targetName) ~= "string" or typeof(amount) ~= "number" then
		return
	end
	local target = Players:FindFirstChild(targetName)
	if not target or target == player then
		return
	end

	local coins = player.leaderstats:FindFirstChild("Coins")
	local targetCoins = target.leaderstats:FindFirstChild("Coins")
	if not coins or not targetCoins or amount > coins.Value then
		return
	end

	coins.Value -= amount -- expect: luau-shield001
	targetCoins.Value += amount -- expect: luau-shield001
end)
