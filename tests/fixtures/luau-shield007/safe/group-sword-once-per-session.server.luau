--!strict
-- Safe: the group sword can be requested once per session. The handler checks
-- and sets checked[player.UserId] before calling the group API, so every
-- later request returns at once (players who join the group mid-session
-- rejoin to get the sword).
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GROUP_ID = 4567890
local ClaimGroupSword = ReplicatedStorage.Remotes.ClaimGroupSword :: RemoteFunction
local checked: { [number]: boolean } = {}

ClaimGroupSword.OnServerInvoke = function(player: Player): boolean
	if checked[player.UserId] then
		return false
	end
	checked[player.UserId] = true
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if not ok then
		return false
	end
	for _, group in groups do
		if group.Id == GROUP_ID then
			ServerStorage.Tools.GroupSword:Clone().Parent = player.Backpack
			return true
		end
	end
	return false
end
