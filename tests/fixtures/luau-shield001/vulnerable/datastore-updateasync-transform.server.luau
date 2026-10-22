--!strict
-- Vulnerable: season pass points live in a DataStore and are updated with
-- UpdateAsync. The client sends how many points the challenge was worth; the
-- server checks the type and that the number is positive, but not the
-- maximum, and the transform function returns the old value plus it.
--
-- Exploit: fire ChallengeComplete with 1e12 to unlock every tier of the pass.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChallengeComplete = ReplicatedStorage.Remotes.ChallengeComplete :: RemoteEvent
local seasonStore = DataStoreService:GetDataStore("SeasonPass_S7")

local COOLDOWN = 5
local lastUpdate: { [Player]: number } = {}

ChallengeComplete.OnServerEvent:Connect(function(player: Player, points: number)
	local now = os.clock()
	if now - (lastUpdate[player] or 0) < COOLDOWN then
		return
	end
	lastUpdate[player] = now

	if typeof(points) ~= "number" or points <= 0 then
		return
	end
	seasonStore:UpdateAsync(`pass_{player.UserId}`, function(old: number?): number -- expect: luau-shield001
		return (old or 0) + points
	end)
end)
