-- Safe (v0.2.0 review): leaving the queue removes the player found with `table.find`; a second request returns.
-- Leave the matchmaking queue: only a player who is in the queue list is
-- removed (table.find + table.remove) before the MemoryStore update. A second
-- request finds nothing and returns. The docs accept the
-- `table.find` + `table.insert` shape for joining.
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaveQueue = ReplicatedStorage.Remotes.LeaveQueue
local queueMap = MemoryStoreService:GetSortedMap("Queue")
local queue: { Player } = {}

LeaveQueue.OnServerEvent:Connect(function(player: Player)
	local index = table.find(queue, player)
	if not index then
		return
	end
	table.remove(queue, index)
	queueMap:RemoveAsync(tostring(player.UserId))
end)
