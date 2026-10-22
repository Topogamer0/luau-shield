-- Safe: donating gems to the server-wide community goal. The bounds are
-- written in a "must be true" form: `amount >= 1 and amount <= gems.Value` is
-- false for NaN, so only real numbers in range run the writes. No separate
-- `amount == amount` test is needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DonateGems = ReplicatedStorage.Remotes.DonateGems :: RemoteEvent
local GoalReached = ReplicatedStorage.Remotes.GoalReached :: RemoteEvent

local communityGoal = { Gems = 0, Target = 1_000_000 }

DonateGems.OnServerEvent:Connect(function(player: Player, amount: number)
	local gems = player.leaderstats.Gems
	if typeof(amount) == "number" and amount >= 1 and amount <= gems.Value then
		gems.Value -= amount
		communityGoal.Gems += amount
		if communityGoal.Gems >= communityGoal.Target then
			GoalReached:FireAllClients(communityGoal.Target)
		end
	end
end)
