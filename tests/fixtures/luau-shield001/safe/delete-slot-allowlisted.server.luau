--!strict
-- Safe: deleting a save slot (twin of the vulnerable datastore-client-key
-- entry). The client only says which of its slots to delete: the slot number
-- must be one of SLOTS (allow-listed), and the key is built on the server
-- from player.UserId, so a player can only ever delete their own slots. A
-- cooldown limits DataStore requests (luau-shield007).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeleteSlot = ReplicatedStorage.Remotes.DeleteSlot :: RemoteEvent
local slotStore = DataStoreService:GetDataStore("SaveSlots_v3")

local SLOTS = { 1, 2, 3 }
local DELETE_COOLDOWN = 10

local lastDelete: { [Player]: number } = {}

-- `slot: number` is only an annotation; table.find below is the real check.
DeleteSlot.OnServerEvent:Connect(function(player: Player, slot: number)
	local now = os.clock()
	if now - (lastDelete[player] or 0) < DELETE_COOLDOWN then
		return
	end
	lastDelete[player] = now

	if not table.find(SLOTS, slot) then
		return
	end
	slotStore:RemoveAsync(`slot_{player.UserId}_{slot}`)
end)
