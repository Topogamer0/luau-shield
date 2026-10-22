--!strict
-- Safe: selling an item. The client sends the item id; the id is allow-listed
-- by the SELL_PRICES table and must be owned, and the coins are computed on
-- the server from the price list (doubled for VIPs). The count written back
-- to the inventory is the server's own count minus one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SellItem = ReplicatedStorage.Remotes.SellItem :: RemoteEvent

local SELL_PRICES: { [string]: number } = {
	Wood = 2,
	IronOre = 15,
	Ruby = 400,
}

type PlayerData = {
	Coins: number,
	VipUntil: number,
	Inventory: { [string]: number },
}

local sessions: { [Player]: PlayerData } = {}

SellItem.OnServerEvent:Connect(function(player: Player, itemId: string)
	local data = sessions[player]
	if not data or typeof(itemId) ~= "string" or not SELL_PRICES[itemId] then
		return
	end
	local count = data.Inventory[itemId]
	if not count or count < 1 then
		return
	end

	local multiplier = if data.VipUntil > os.time() then 2 else 1
	data.Inventory[itemId] = count - 1
	data.Coins += SELL_PRICES[itemId] * multiplier
end)

Players.PlayerAdded:Connect(function(player)
	sessions[player] = { Coins = 0, VipUntil = 0, Inventory = {} }
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
