-- Safe: round rewards (twin of the vulnerable profile-data-write entry).
-- Kills and wins are recorded by the server while the round runs (combat is
-- resolved server-side). When a round ends the client asks to claim the
-- rewards of that round by id; the id only selects a server-owned record.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileManager = require(ServerScriptService.Modules.ProfileManager)
local RoundSystem = require(ServerScriptService.Modules.RoundSystem)

local ClaimRoundRewards = ReplicatedStorage.Remotes.ClaimRoundRewards :: RemoteFunction

local XP_PER_KILL = 25
local XP_PER_WIN = 100

type Result = { Kills: number, Won: boolean, Claimed: boolean }

local finishedRounds: { [string]: { [Player]: Result } } = {}

RoundSystem.RoundEnded:Connect(function(roundId: string, results: { [Player]: Result })
	finishedRounds[roundId] = results
end)

ClaimRoundRewards.OnServerInvoke = function(player: Player, roundId: string)
	local results = finishedRounds[roundId]
	local result = results and results[player]
	if not result or result.Claimed then
		return nil
	end
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return nil
	end
	result.Claimed = true

	local xp = result.Kills * XP_PER_KILL + (if result.Won then XP_PER_WIN else 0)
	profile.Data.Kills += result.Kills
	profile.Data.Wins += if result.Won then 1 else 0
	profile.Data.XP += xp
	return { kills = result.Kills, xp = xp }
end
