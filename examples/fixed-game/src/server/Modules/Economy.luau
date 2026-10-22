-- Coin helpers used by the shop, the trading system and the admin tools.
-- The saved profile and the leaderboard value are always updated together.
--
-- Callers validate what they pass in; the asserts below are a second line of
-- defence so that a negative, fractional or NaN amount can never reach the
-- saved data.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validate = require(ReplicatedStorage.Shared.Validate)
local DataManager = require(script.Parent.DataManager)

local MAX_TRANSACTION = 1_000_000_000

local Economy = {}

function Economy.getCoins(player: Player): number
	local profile = DataManager.get(player)
	return if profile then profile.Coins else 0
end

function Economy.addCoins(player: Player, amount: number)
	assert(Validate.isIntegerInRange(amount, 0, MAX_TRANSACTION), "invalid coin amount")
	local profile = DataManager.get(player)
	if not profile then
		return
	end
	profile.Coins += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value += amount
	end
end

-- Removes `cost` coins when the player can afford it.
function Economy.trySpend(player: Player, cost: number): boolean
	assert(Validate.isIntegerInRange(cost, 0, MAX_TRANSACTION), "invalid coin amount")
	local profile = DataManager.get(player)
	if not profile or profile.Coins < cost then
		return false
	end
	profile.Coins -= cost
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Coins.Value -= cost
	end
	return true
end

return Economy
