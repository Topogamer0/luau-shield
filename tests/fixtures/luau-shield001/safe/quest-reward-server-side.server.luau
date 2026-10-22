-- Safe: quest rewards with a speed bonus, measured on the server. The client
-- picks which quest to start (allow-listed by the QUESTS table) and says when
-- it is done; the server checks that the character is at the quest's finish
-- line and computes the elapsed time itself. Reward and bonus are server
-- values, so the `x.Value = x.Value + ...` write is fine.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StartQuest = ReplicatedStorage.Remotes.StartQuest :: RemoteEvent
local CompleteQuest = ReplicatedStorage.Remotes.CompleteQuest :: RemoteEvent

type Quest = { Reward: number, ParTime: number, Finish: BasePart }

local QUESTS: { [string]: Quest } = {
	Lumberjack = { Reward = 150, ParTime = 120, Finish = workspace.Quests.Lumberjack.Finish },
	Miner = { Reward = 300, ParTime = 240, Finish = workspace.Quests.Miner.Finish },
}
local BONUS_PER_SECOND = 5
local FINISH_RADIUS = 15

local active: { [Player]: { id: string, startedAt: number } } = {}

StartQuest.OnServerEvent:Connect(function(player: Player, questId: unknown)
	if typeof(questId) == "string" and QUESTS[questId] and not active[player] then
		active[player] = { id = questId, startedAt = os.clock() }
	end
end)

CompleteQuest.OnServerEvent:Connect(function(player: Player)
	local run = active[player]
	if not run or not player.Character then
		return
	end
	local quest = QUESTS[run.id]
	if player:DistanceFromCharacter(quest.Finish.Position) > FINISH_RADIUS then
		return
	end
	active[player] = nil

	local elapsed = os.clock() - run.startedAt
	local bonus = math.floor(math.max(0, quest.ParTime - elapsed) * BONUS_PER_SECOND)
	player.leaderstats.Cash.Value = player.leaderstats.Cash.Value + quest.Reward + bonus
end)

Players.PlayerRemoving:Connect(function(player)
	active[player] = nil
end)
