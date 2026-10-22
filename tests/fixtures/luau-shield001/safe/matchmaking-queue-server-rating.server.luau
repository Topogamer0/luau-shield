--!strict
-- Safe: ranked matchmaking with a MemoryStore queue (twin of the vulnerable
-- matchmaking-queue-client-rating entry). The client only picks a region,
-- which is allow-listed; the rating comes from the server's copy of the
-- player's ranked data. A cooldown limits MemoryStore requests (luau-shield007).

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JoinRanked = ReplicatedStorage.Remotes.JoinRanked :: RemoteEvent
local rankedQueue = MemoryStoreService:GetQueue("RankedMatchmaking")

local REGIONS = { "EU", "NA", "AS", "OCE" }
local QUEUE_TTL = 120
local JOIN_COOLDOWN = 5
local STARTING_RATING = 1_000

export type QueueEntry = { userId: number, region: string, rating: number }

local ratings: { [Player]: number } = {}
local lastJoin: { [Player]: number } = {}

JoinRanked.OnServerEvent:Connect(function(player: Player, region: string)
	local now = os.clock()
	if now - (lastJoin[player] or -math.huge) < JOIN_COOLDOWN then
		return
	end
	lastJoin[player] = now

	local rating = ratings[player]
	if not rating or not table.find(REGIONS, region) then
		return
	end
	local entry: QueueEntry = { userId = player.UserId, region = region, rating = rating }
	rankedQueue:AddAsync(entry, QUEUE_TTL)
end)

Players.PlayerAdded:Connect(function(player)
	-- The real game loads the rating from the ranked DataStore here.
	ratings[player] = STARTING_RATING
end)

Players.PlayerRemoving:Connect(function(player)
	ratings[player] = nil
	lastJoin[player] = nil
end)
