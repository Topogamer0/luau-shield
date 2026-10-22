-- Safe: exchanging gems for coins at a fixed rate. The checks are written as
-- `if not (... and amount >= 1 and amount <= gems.Value) then return end`:
-- the comparisons inside the parentheses must be true for the exchange to go
-- ahead, and they are false for NaN, so NaN is rejected without a separate
-- `amount ~= amount` test. `amount % 1 == 0` keeps the exchange to whole gems.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExchangeGems = ReplicatedStorage.Remotes.ExchangeGems :: RemoteEvent

local COINS_PER_GEM = 250

local function onExchange(player: Player, amount: unknown)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local gems = leaderstats:FindFirstChild("Gems") :: IntValue?
	local coins = leaderstats:FindFirstChild("Coins") :: IntValue?
	if not gems or not coins then
		return
	end
	if not (typeof(amount) == "number" and amount % 1 == 0 and amount >= 1 and amount <= gems.Value) then
		return
	end
	gems.Value -= amount
	coins.Value += amount * COINS_PER_GEM
end

ExchangeGems.OnServerEvent:Connect(onExchange)
