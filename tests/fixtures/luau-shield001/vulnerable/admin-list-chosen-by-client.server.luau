-- Vulnerable (v0.2.0 review): the admins of a clan the client picked are not the game's admins.
-- Per-server / per-clan admin lists: the client picks which list is checked.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local data = {}

-- Every clan leader is an admin of their own clan.
local clanAdmins = {} -- clanId -> { [userId] = true }

ReplicatedStorage.Remotes.CreateClan.OnServerEvent:Connect(function(player, name)
	local clanId = #clanAdmins + 1
	clanAdmins[clanId] = { [player.UserId] = true }
end)

ReplicatedStorage.Remotes.ClanGiveA.OnServerEvent:Connect(function(player, clanId, userId, amount)
	if not clanAdmins[clanId][player.UserId] then
		return
	end
	data[userId].Coins += amount -- expect: luau-shield001
end)

local clanModerators = {} -- clanId -> { userId, ... }
ReplicatedStorage.Remotes.ClanGiveB.OnServerEvent:Connect(function(player, clanId, userId, amount)
	if not table.find(clanModerators[clanId], player.UserId) then
		return
	end
	data[userId].Coins += amount -- expect: luau-shield001
end)
