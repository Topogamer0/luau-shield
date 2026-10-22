--!strict
-- Vulnerable: ranked matchmaking across servers with a MemoryStore queue. The
-- region is allow-listed, but the rating that the matchmaker uses to group
-- players is sent by the client and only type-checked before it is queued.
--
-- Exploit: a top player fires JoinRanked("EU", 0) to be matched against
-- beginners and farm rating from them.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JoinRanked = ReplicatedStorage.Remotes.JoinRanked :: RemoteEvent
local rankedQueue = MemoryStoreService:GetQueue("RankedMatchmaking")

local REGIONS = { "EU", "NA", "AS", "OCE" }
local QUEUE_TTL = 120
local JOIN_COOLDOWN = 5

export type QueueEntry = { userId: number, region: string, rating: number }

local lastJoin: { [Player]: number } = {}

JoinRanked.OnServerEvent:Connect(function(player: Player, region: string, rating: number)
	local now = os.clock()
	if now - (lastJoin[player] or -math.huge) < JOIN_COOLDOWN then
		return
	end
	lastJoin[player] = now

	if not table.find(REGIONS, region) or typeof(rating) ~= "number" then
		return
	end
	local entry: QueueEntry = { userId = player.UserId, region = region, rating = rating }
	rankedQueue:AddAsync(entry, QUEUE_TTL) -- expect: luau-shield001
end)
