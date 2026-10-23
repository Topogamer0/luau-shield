-- Vulnerable (v0.2.0 review): any player can join a group; `GetRankInGroup(G) >= 1` is a membership check.
-- "Join our group for a reward" button: any player can join the group, so
-- GetRankInGroup(GROUP) >= 1 is a membership check, not a permission check.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GROUP_ID = 4567890
local data = {}

ReplicatedStorage.Remotes.ClaimGroupReward.OnServerEvent:Connect(function(player, amount)
	if player:GetRankInGroup(GROUP_ID) >= 1 then
		data[player].Coins += amount -- expect: luau-shield001
	end
end)

ReplicatedStorage.Remotes.ClaimGroupChest.OnServerEvent:Connect(function(player, amount)
	if player:GetRankInGroup(GROUP_ID) == 0 then
		return
	end
	data[player].Gems += amount -- expect: luau-shield001
end)

ReplicatedStorage.Remotes.MemberDoor.OnServerEvent:Connect(function(player, amount)
	if player:GetRankInGroup(GROUP_ID) > 0 then
		data[player].Coins += amount -- expect: luau-shield001
	end
end)
