--!strict
-- Vulnerable: the Magnet gamepass pulls nearby drops to the player. The client
-- works out which drops were in range and reports { [itemId]: count }. Every
-- count is fully checked (number, not NaN, 1 to MAX_STACK), but the item ids
-- are used as keys of the saved inventory without being looked up in the
-- item catalog.
--
-- Exploit: fire MagnetCollect with { RainbowDragonEgg = 5 } to get an item
-- that only dropped during a past event, or one that is not released yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Modules.ProfileStore)

local MagnetCollect = ReplicatedStorage.Remotes.MagnetCollect :: RemoteEvent

local MAX_STACK = 5

MagnetCollect.OnServerEvent:Connect(function(player: Player, collected: { [string]: number })
	local profile = ProfileStore.Profiles[player]
	if not profile or typeof(collected) ~= "table" then
		return
	end
	local inventory = profile.Data.Inventory
	for itemId, count in collected do
		if typeof(count) ~= "number" or count ~= count or count < 1 or count > MAX_STACK then
			continue
		end
		inventory[itemId] = (inventory[itemId] or 0) + count -- expect: luau-shield001
	end
end)
