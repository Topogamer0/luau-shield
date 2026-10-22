--!strict
-- Vulnerable: a Knit service lets the client pick up world items. The item
-- name chosen by the client is used as a key of the saved inventory without
-- checking that such an item exists or that a drop of it is near the player.
--
-- Exploit: Knit exposes Client methods as remotes, so the exploiter calls
-- InventoryService.PickUp("DeveloperHammer") and owns any item, including
-- ones that never spawn in the world.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

type PlayerData = {
	Inventory: { [string]: boolean },
}

local sessions: { [Player]: PlayerData } = {}

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {},
})

function InventoryService.Client:PickUp(player: Player, itemName: string): boolean
	if typeof(itemName) ~= "string" then
		return false
	end
	local data = sessions[player]
	if not data then
		return false
	end
	data.Inventory[itemName] = true -- expect: luau-shield001
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
