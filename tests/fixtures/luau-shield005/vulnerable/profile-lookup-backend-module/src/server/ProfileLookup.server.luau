--!strict
-- Vulnerable: the profile card looks up a player by username through the
-- Backend module (required from script.Parent). The handler only checks the
-- type, and Backend.fetchProfile interpolates the name into the URL path, so
-- the finding is reported inside the module, on the GetAsync call.
--
-- Exploit: LookupProfile:InvokeServer("../admin/keys") or
-- "someone?fields=email,ip" makes the server request another endpoint (or
-- private fields) with its own bearer token, and the decoded response is
-- returned to the exploiter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Backend = require(script.Parent.Backend)

local LookupProfile = ReplicatedStorage.Remotes.LookupProfile :: RemoteFunction

local LOOKUP_COOLDOWN = 2
local lastLookup: { [Player]: number } = {}

LookupProfile.OnServerInvoke = function(player: Player, username: string): Backend.Profile?
	local now = os.clock()
	if now - (lastLookup[player] or 0) < LOOKUP_COOLDOWN then
		return nil
	end
	lastLookup[player] = now

	if typeof(username) ~= "string" then
		return nil
	end
	return Backend.fetchProfile(username)
end
