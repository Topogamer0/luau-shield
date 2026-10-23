-- Vulnerable (v0.2.0 review): `clan:isModerator(player)` on a clan the client picked is not a permission check.
-- Clans: any player can create a clan and becomes its owner/moderator.
-- Clan moderators can pay members out of the clan bank.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Clans = require(ServerScriptService.Clans)
local data = {}

ReplicatedStorage.Remotes.ClanPayout.OnServerEvent:Connect(function(player, clanId, amount)
	local clan = Clans.get(clanId)
	if not clan or not clan:isModerator(player) then
		return
	end
	data[player].Coins += amount -- expect: luau-shield001
end)
