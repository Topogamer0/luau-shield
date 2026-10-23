-- HD Admin / Adonis style ranks: 0 = player, 1 = VIP, 2 = mod, 3 = admin,
-- 4 = head admin, 5 = owner.
local Players = game:GetService("Players")
local AdminRanks = {}

local GROUP_ID = 4567890
local RANKS_BY_USER = {
	[12345] = 5,
	[67890] = 3,
}

function AdminRanks.getRank(player: Player): number
	if player.UserId == game.CreatorId then
		return 5
	end
	local rank = RANKS_BY_USER[player.UserId]
	if rank then
		return rank
	end
	if player:GetRankInGroup(GROUP_ID) >= 200 then
		return 2
	end
	return 0
end

function AdminRanks.GetLevel(player: Player): number
	return AdminRanks.getRank(player) * 100
end

function AdminRanks.CheckAdmin(player: Player): boolean
	return AdminRanks.getRank(player) >= 3
end

return AdminRanks
