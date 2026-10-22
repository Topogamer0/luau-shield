-- Coin helpers shared by the server scripts. The leaderstats value is the
-- source of truth; the data script saves it when the player leaves.
--
-- The helpers do not check `amount` themselves: callers must pass a server
-- value or a value they validated (TipService does).

local Economy = {}

function Economy.getCoins(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	return if coins then coins.Value else 0
end

function Economy.addCoins(player: Player, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local coins = leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Value += amount
	end
end

-- Removes `cost` coins when the player can afford it.
function Economy.trySpend(player: Player, cost: number): boolean
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if not coins or coins.Value < cost then
		return false
	end
	coins.Value -= cost
	return true
end

return Economy
