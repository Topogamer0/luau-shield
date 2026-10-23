-- Vulnerable (v0.2.0 review): a group id or a minimum rank sent by the client proves nothing.
-- The rank threshold or the group comes from the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GROUP_ID = 4567890
local data = {}

ReplicatedStorage.Remotes.RankGate.OnServerEvent:Connect(function(player, requiredRank, amount)
	if player:GetRankInGroup(GROUP_ID) < requiredRank then
		return
	end
	data[player].Coins += amount -- expect: luau-shield001
end)

ReplicatedStorage.Remotes.GroupGate.OnServerEvent:Connect(function(player, groupId, amount)
	if player:GetRankInGroup(groupId) < 254 then
		return
	end
	data[player].Coins += amount -- expect: luau-shield001
end)
