-- Vulnerable (v0.2.0 review): the state table is created by each request: it limits nothing.
-- Beginner mistake: the state table is declared INSIDE the handler, so each
-- request gets a new, empty table and the test always passes. Every request
-- clones the reward. (The handler-local `local claimed = false` version is
-- reported since review1; a handler-local table is not.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClaimDaily = ReplicatedStorage.Remotes.ClaimDaily
local Reward = ServerStorage.Rewards.DailyChest

ClaimDaily.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local claimState: { [Player]: string } = {}
	if claimState[player] == "Claimed" then
		return
	end
	claimState[player] = "Claimed"
	Reward:Clone().Parent = player.Backpack
end)
