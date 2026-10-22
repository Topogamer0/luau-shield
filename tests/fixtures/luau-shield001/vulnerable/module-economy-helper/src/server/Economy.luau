-- Coin helpers shared by the server scripts. The leaderstats value is the
-- source of truth; the data script saves it when the player leaves.
--
-- Nothing in here checks `amount`: every caller is trusted to pass a value it
-- computed on the server. ChestService breaks that assumption.

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
		coins.Value += amount -- expect: luau-shield001
	end
end

return Economy
