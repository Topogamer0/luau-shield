-- Vulnerable: quest rewards with a speed bonus. The base reward comes from
-- the server's quest table, but the time the quest took is measured and sent
-- by the client. math.max(0, ...) gives the bonus a lower bound only.
--
-- Exploit: fire CompleteQuest with ("Lumberjack", -1e9): the "speed bonus"
-- is worth billions of cash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CompleteQuest = ReplicatedStorage.Remotes.CompleteQuest :: RemoteEvent

type Quest = { Reward: number, ParTime: number }

local QUESTS: { [string]: Quest } = {
	Lumberjack = { Reward = 150, ParTime = 120 },
	Miner = { Reward = 300, ParTime = 240 },
}
local BONUS_PER_SECOND = 5

local completed: { [Player]: { [string]: boolean } } = {}

local function onCompleteQuest(player: Player, questId: string, timeTaken: number)
	local quest = QUESTS[questId]
	local done = completed[player]
	if not quest or not done or done[questId] then
		return
	end
	done[questId] = true

	local bonus = math.max(0, quest.ParTime - timeTaken) * BONUS_PER_SECOND
	player.leaderstats.Cash.Value = player.leaderstats.Cash.Value + quest.Reward + bonus -- expect: luau-shield001
end

Players.PlayerAdded:Connect(function(player)
	completed[player] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	completed[player] = nil
end)

CompleteQuest.OnServerEvent:Connect(onCompleteQuest)
