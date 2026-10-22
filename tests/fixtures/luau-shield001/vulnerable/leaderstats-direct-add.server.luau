-- Vulnerable: coin pickups are detected on the client, which then reports how
-- many coins it collected. The server adds that number to leaderstats. The
-- `amount: number` annotation is erased at runtime and the typeof check only
-- proves that the value is a number, not that it is a sane one.
--
-- Exploit: an executor fires CollectCoins with 1e9 once and the player tops
-- the leaderboard; the value is saved with the rest of the stats on leave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectCoins = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CollectCoins") :: UnreliableRemoteEvent

CollectCoins.OnServerEvent:Connect(function(player: Player, amount: number)
	if typeof(amount) ~= "number" then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	leaderstats.Coins.Value += amount -- expect: luau-shield001
end)
