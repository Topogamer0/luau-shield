-- Coin helpers used by the shop and the trading system. The saved profile
-- and the leaderboard value are always updated together.

local DataManager = require(script.Parent.DataManager)

local Economy = {}

function Economy.getCoins(player: Player): number
	local profile = DataManager.get(player)
	return if profile then profile.Coins else 0
end

function Economy.addCoins(player: Player, amount: number)
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
