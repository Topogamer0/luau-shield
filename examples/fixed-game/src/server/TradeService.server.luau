-- Coin gifts between players. The receiver confirms the offer in a prompt
-- on their screen before any coins move. The confirmation is a RemoteEvent
-- (TradeRequest -> RespondTrade), so the server never yields on a client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Validate = require(ReplicatedStorage.Shared.Validate)
local Economy = require(script.Parent.Modules.Economy)
local Remotes = require(script.Parent.Modules.Remotes)

type Offer = { from: Player, amount: number, expires: number }

local OFFER_TIMEOUT = 30
local pendingOffers: { [Player]: Offer } = {}

Remotes.OfferTrade.OnServerEvent:Connect(function(player: Player, targetUserId: unknown, coins: unknown)
	if typeof(targetUserId) ~= "number" or not Validate.isIntegerInRange(coins, 1, Config.MaxTradeCoins) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	local pending = pendingOffers[target]
	if pending and os.clock() < pending.expires then
		return -- the receiver is still answering another offer
	end
	if Economy.getCoins(player) < coins then
		return -- cannot offer more than you have
	end
	pendingOffers[target] = { from = player, amount = coins, expires = os.clock() + OFFER_TIMEOUT }
	Remotes.TradeRequest:FireClient(target, player.Name, coins)
end)

Remotes.RespondTrade.OnServerEvent:Connect(function(player: Player, accepted: unknown)
	local offer = pendingOffers[player]
	if not offer or typeof(accepted) ~= "boolean" then
		return
	end
	pendingOffers[player] = nil
	if not accepted or os.clock() > offer.expires or not offer.from.Parent then
		return -- declined, expired, or the sender left
	end
	-- trySpend checks the balance again: it may have changed since the offer.
	if Economy.trySpend(offer.from, offer.amount) then
		Economy.addCoins(player, offer.amount)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	pendingOffers[player] = nil
end)
