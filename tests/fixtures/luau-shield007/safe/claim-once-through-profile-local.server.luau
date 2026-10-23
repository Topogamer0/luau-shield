-- Safe (v0.2.0 review): a one-time reward claimed through a local copy of the profile.
-- Safe: the starter sword can be claimed once per session. The flag lives in
-- the player's profile (fetched into a local first, as most games do) and is
-- set before the clone, so a second request returns early.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClaimStarter = ReplicatedStorage.Remotes.ClaimStarter
local Profiles = {} -- [player] = { Data = { StarterClaimed = false } }

ClaimStarter.OnServerEvent:Connect(function(player)
	local profile = Profiles[player]
	if not profile then
		return
	end
	if profile.Data.StarterClaimed then
		return
	end
	profile.Data.StarterClaimed = true
	local sword = ServerStorage.StarterSword:Clone()
	sword.Parent = player.Backpack
end)
