--!strict
-- Safe: buying several potions at once. The arguments are checked with the t
-- library: t.tuple applies t.string to the potion id and
-- t.numberConstrained(1, MAX_QUANTITY) to the quantity (type, both bounds and
-- NaN rejected), and t.integer rejects fractions. The potion id must be a key
-- of the server's POTIONS table, which also gives the price.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local BuyPotions = ReplicatedStorage.Remotes.BuyPotions :: RemoteFunction

local MAX_QUANTITY = 25
local POTIONS: { [string]: number } = {
	Speed = 40,
	Jump = 40,
	Luck = 150,
}

type Session = { Gold: number, Potions: { [string]: number } }

local sessions: { [Player]: Session } = {}
local checkPurchase = t.tuple(t.string, t.numberConstrained(1, MAX_QUANTITY))

BuyPotions.OnServerInvoke = function(player: Player, potionId: string, quantity: number): boolean
	local session = sessions[player]
	if not session or not checkPurchase(potionId, quantity) or not t.integer(quantity) then
		return false
	end
	if not POTIONS[potionId] then
		return false
	end
	local cost = POTIONS[potionId] * quantity
	if session.Gold < cost then
		return false
	end
	session.Gold -= cost
	session.Potions[potionId] = (session.Potions[potionId] or 0) + quantity
	return true
end

Players.PlayerAdded:Connect(function(player)
	sessions[player] = { Gold = 0, Potions = {} }
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
