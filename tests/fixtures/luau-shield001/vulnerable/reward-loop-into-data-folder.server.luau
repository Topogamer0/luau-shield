-- Vulnerable (v0.2.0 review): rewards written through a loop key into IntValues; `gems` is the client's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.CompleteQuest

-- Rewards go into the IntValues of the player's "Data" folder (saved on leave).
local function giveRewards(player, rewards)
	local data = player:FindFirstChild("Data")
	if not data then return end
	for name, amount in pairs(rewards) do
		data[name].Value += amount -- expect: luau-shield001
	end
end

remote.OnServerEvent:Connect(function(player, questId, gems)
	giveRewards(player, { Coins = 50, Gems = gems })
end)
