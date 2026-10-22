--!strict
-- Safe: equipping cosmetics. The client chooses both the key and the value of
-- a saved table, but the key is allow-listed (it must be a known cosmetic
-- that the player owns) and the value has passed a boolean type check, so it
-- can only be true or false.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SetEquipped = ReplicatedStorage.Remotes.SetEquipped :: RemoteEvent

local COSMETICS: { [string]: { Slot: string } } = {
	PirateHat = { Slot = "Head" },
	RedCape = { Slot = "Back" },
	FireTrail = { Slot = "Trail" },
}

type PlayerData = {
	Inventory: { [string]: boolean },
	Equipped: { [string]: boolean },
}

local sessions: { [Player]: PlayerData } = {}

SetEquipped.OnServerEvent:Connect(function(player: Player, cosmeticId: unknown, equipped: unknown)
	if typeof(cosmeticId) ~= "string" or typeof(equipped) ~= "boolean" then
		return
	end
	if not COSMETICS[cosmeticId] then
		return
	end
	local data = sessions[player]
	if not data or not data.Inventory[cosmeticId] then
		return
	end
	data.Equipped[cosmeticId] = equipped
end)

Players.PlayerAdded:Connect(function(player)
	sessions[player] = { Inventory = {}, Equipped = {} }
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
