-- Vulnerable (v0.2.0 review): a permission module picked with a client key proves nothing.
-- Clan system: each clan has its own role table. The client picks the clan,
-- so `isModerator` answers "is the player a moderator of a clan they chose"
-- (their own clan), not "is the player a game moderator".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ClanRoles = require(ServerScriptService.ClanRoles)
local Permissions = require(ServerScriptService.Permissions)
local data = {}

ReplicatedStorage.Remotes.ClanGrant.OnServerEvent:Connect(function(player, clanId, userId, amount)
	if not ClanRoles[clanId]:isModerator(player) then
		return
	end
	data[userId].Coins += amount -- expect: luau-shield001
end)

ReplicatedStorage.Remotes.ClanGrant2.OnServerEvent:Connect(function(player, clanId, userId, amount)
	local roles = ClanRoles.forClan(clanId)
	if not roles:isModerator(player) then
		return
	end
	data[userId].Coins += amount -- expect: luau-shield001
end)

ReplicatedStorage.Remotes.ScopedGrant.OnServerEvent:Connect(function(player, scope, userId, amount)
	if not Permissions.scopes[scope].hasPermission(player, "Grant") then
		return
	end
	data[userId].Coins += amount -- expect: luau-shield001
end)
