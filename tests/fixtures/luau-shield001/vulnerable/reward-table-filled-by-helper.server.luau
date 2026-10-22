-- Vulnerable (v0.2.0 review): a helper adds the client's bonus to a reward table the handler then pays out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.ClaimReward

local function addBonus(rewards, bonus)
	rewards.Gems = bonus
end

remote.OnServerEvent:Connect(function(player, bonus)
	local rewards = { Coins = 10 }
	addBonus(rewards, bonus)
	for stat, amount in pairs(rewards) do
		player.leaderstats[stat].Value += amount -- expect: luau-shield001
	end
end)
