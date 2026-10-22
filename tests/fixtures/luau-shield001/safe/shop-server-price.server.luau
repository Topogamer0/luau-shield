--!strict
-- Safe: shop purchase. The client only sends the id of the item it wants.
-- The id is allow-listed by the server catalog before it is used as an
-- inventory key, and the price always comes from the catalog, never from the
-- client. A short cooldown covers the :Clone() call (luau-shield007).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BuyItem = ReplicatedStorage.Remotes.BuyItem :: RemoteEvent
local Tools = ServerStorage:WaitForChild("Tools")

type Item = { Price: number, Tool: string }

local CATALOG: { [string]: Item } = {
	Sword = { Price = 100, Tool = "ClassicSword" },
	Slingshot = { Price = 250, Tool = "Slingshot" },
	RocketLauncher = { Price = 5_000, Tool = "RocketLauncher" },
}
local PURCHASE_COOLDOWN = 0.5

local inventories: { [Player]: { [string]: boolean } } = {}
local lastPurchase: { [Player]: number } = {}

BuyItem.OnServerEvent:Connect(function(player: Player, itemId: string)
	local now = os.clock()
	if now - (lastPurchase[player] or 0) < PURCHASE_COOLDOWN then
		return
	end
	lastPurchase[player] = now

	if typeof(itemId) ~= "string" or not CATALOG[itemId] then
		return
	end
	local item = CATALOG[itemId]
	local inventory = inventories[player]
	local coins = (player :: any).leaderstats.Coins :: IntValue
	if not inventory or inventory[itemId] or coins.Value < item.Price then
		return
	end

	coins.Value -= item.Price
	inventory[itemId] = true

	local template = Tools:FindFirstChild(item.Tool)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if template and backpack then
		template:Clone().Parent = backpack
	end
end)

Players.PlayerAdded:Connect(function(player)
	inventories[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	inventories[player] = nil
	lastPurchase[player] = nil
end)
