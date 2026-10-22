-- Vulnerable: match results reported by the client. The server only checks
-- that it received a table, then adds the numbers to the saved profile
-- (ProfileStore-style `profile.Data`).
--
-- Exploit: invoke ReportMatch with { kills = 1e6, xp = 1e9 } after any round
-- to top the kill leaderboard and reach the maximum level instantly. The
-- profile is saved, so the stats survive rejoining.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileManager = require(ServerScriptService.Modules.ProfileManager)

local ReportMatch = ReplicatedStorage.Remotes.ReportMatch :: RemoteFunction

type MatchResult = {
	kills: number,
	xp: number,
}

ReportMatch.OnServerInvoke = function(player: Player, result: MatchResult): boolean
	if typeof(result) ~= "table" then
		return false
	end
	local profile = ProfileManager.Profiles[player]
	if not profile then
		return false
	end

	profile.Data.Kills += result.kills -- expect: luau-shield001
	profile.Data.XP += result.xp -- expect: luau-shield001
	return true
end
