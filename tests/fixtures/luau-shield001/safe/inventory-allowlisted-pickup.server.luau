--!strict
-- Safe: Knit pick-up (twin of the vulnerable inventory-dynamic-key entry).
-- The item name must be a key of the server's ITEMS catalog (allow-list), and
-- a drop of that item must be lying within reach of the character. Only then
-- is the name used as an inventory key.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ITEMS: { [string]: { Rarity: string } } = {
	Wood = { Rarity = "Common" },
	IronOre = { Rarity = "Common" },
	Ruby = { Rarity = "Rare" },
}
local PICKUP_RANGE = 10

type PlayerData = {
	Inventory: { [string]: boolean },
}

local sessions: { [Player]: PlayerData } = {}
local drops = workspace:WaitForChild("Drops")

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {},
})

function InventoryService.Client:PickUp(player: Player, itemName: string): boolean
	if typeof(itemName) ~= "string" or not ITEMS[itemName] then
		return false
	end
	local data = sessions[player]
	local drop = drops:FindFirstChild(itemName)
	if not data or not player.Character or not drop or not drop:IsA("BasePart") then
		return false
	end
	if player:DistanceFromCharacter(drop.Position) > PICKUP_RANGE then
		return false
	end

	drop:Destroy()
	data.Inventory[itemName] = true
	return true
end

function InventoryService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		sessions[player] = { Inventory = {} }
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

Knit.Start():catch(warn)
