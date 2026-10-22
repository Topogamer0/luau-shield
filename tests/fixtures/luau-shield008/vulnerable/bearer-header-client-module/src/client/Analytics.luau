-- Vulnerable: a client module (StarterPlayerScripts) with a hard-coded bearer
-- token for the analytics API.
local Analytics = {}

Analytics.Headers = {
	Authorization = "Bearer 7c1f0e9d8b6a5c4e3f2a1b0c9d8e7f6a", -- expect: luau-shield008
	["Content-Type"] = "application/json",
}

return Analytics
