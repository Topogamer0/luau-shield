-- Vulnerable (v0.2.0 review): checks stored in a table by a helper are about the item price, not the client's amount.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.BuyItem
local ITEMS = require(ReplicatedStorage.Shared.Items)

-- Sanity checks on the server's own catalog entry.
local function checkItem(item)
	local amount = item.Price
	local priceOk = typeof(amount) == "number" and amount == amount and amount >= 0 and amount <= 1000000
	local stockOk = item.Stock ~= nil
	return { price = priceOk, stock = stockOk }
end

remote.OnServerEvent:Connect(function(player, itemId, amount)
	local item = ITEMS[itemId]
	if not item then return end
	local checks = checkItem(item)
	for _, ok in pairs(checks) do
		if not ok then
			return
		end
	end
	-- `amount` (the quantity sent by the client) is never checked.
	player.leaderstats.Coins.Value -= item.Price * amount -- expect: luau-shield001
end)
