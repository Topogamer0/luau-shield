-- Vulnerable: deleting a save slot. The client sends the full DataStore key
-- of the slot to delete, and the server only checks that the key contains the
-- player's UserId somewhere (an unanchored, plain-text search).
--
-- Exploit: a player whose UserId is 42 fires DeleteSlot with
-- "slot_1420057_2": the key contains "42", so another player's save is wiped.
-- Keys must be built on the server from player.UserId and a validated slot
-- number.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeleteSlot = ReplicatedStorage.Remotes.DeleteSlot :: RemoteEvent
local slotStore = DataStoreService:GetDataStore("SaveSlots_v3")

local DELETE_COOLDOWN = 10
local lastDelete: { [Player]: number } = {}

DeleteSlot.OnServerEvent:Connect(function(player: Player, slotKey: string)
	local now = os.clock()
	if now - (lastDelete[player] or 0) < DELETE_COOLDOWN then
		return
	end
	lastDelete[player] = now

	if typeof(slotKey) ~= "string" or not string.find(slotKey, tostring(player.UserId), 1, true) then
		return
	end
	slotStore:RemoveAsync(slotKey) -- expect: luau-shield001
end)
