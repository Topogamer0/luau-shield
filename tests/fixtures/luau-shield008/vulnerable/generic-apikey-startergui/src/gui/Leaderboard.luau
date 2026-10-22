--!strict
-- Vulnerable: a GUI module under StarterGui (replicated to every client) holds
-- the key of the studio's leaderboard backend.
local Leaderboard = {}

local apiKey = "lb_9f3K2m8Q1x7Z4v6N0p5R2t8W" -- expect: luau-shield008

function Leaderboard.headers(): { [string]: string }
	return { ["X-Api-Key"] = apiKey }
end

return Leaderboard
