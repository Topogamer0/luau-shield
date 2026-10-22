--!strict
-- Vulnerable: the shop asks the buyer to confirm each purchase through the
-- shared Net helper, which waits on the client without a timeout. An exploiter
-- spams BuyItem and never answers: every request parks one more server
-- thread (with its closure) until they leave.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Remotes = ReplicatedStorage.Remotes
local BuyItem = Remotes.BuyItem :: RemoteEvent
local ConfirmPurchase = Remotes.ConfirmPurchase :: RemoteFunction

local PRICES: { [string]: number } = { Sword = 100, Shield = 250 }

BuyItem.OnServerEvent:Connect(function(player: Player, itemId: unknown)
	if typeof(itemId) ~= "string" or not PRICES[itemId] then
		return
	end
	local price = PRICES[itemId]
	local ok, confirmed = Net.invoke(ConfirmPurchase, player, `Buy {itemId} for {price} coins?`)
	if not ok or confirmed ~= true then
		return
	end
	local coins = player.leaderstats.Coins
	if coins.Value >= price then
		coins.Value -= price
	end
end)
