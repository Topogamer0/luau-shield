-- Safe (v0.2.0 review): a generic assign helper copies into a table built for the reply, not into saved data.
-- The shop shows what a purchase would cost before the player confirms it.
-- Nothing is saved: the quote is only returned to the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)

local ITEMS = { Sword = { Coins = 100 }, Bow = { Coins = 80 } }

ReplicatedStorage.Remotes.GetQuote.OnServerInvoke = function(player, itemId, quantity)
	local item = ITEMS[itemId]
	if not item then
		return nil
	end
	return TableUtil.assign({ Coins = 0, Gems = 0 }, { Coins = item.Coins * quantity })
end
