--!strict
-- Safe: profile card lookups (twin of the vulnerable
-- profile-lookup-backend-module entry). Before the username reaches
-- Backend.fetchProfile, which interpolates it into the URL path, it must
-- pass Validate.isUsername from the shared module. luau-shield follows both
-- requires: the validator proves an anchored pattern, so the URL built in
-- Backend can only point at /profiles/<name>.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validate = require(ReplicatedStorage.Shared.Validate)
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

	if not Validate.isUsername(username) then
		return nil
	end
	return Backend.fetchProfile(username)
end
