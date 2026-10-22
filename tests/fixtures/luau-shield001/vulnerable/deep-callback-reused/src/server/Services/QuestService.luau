local ServerScriptService = game:GetService("ServerScriptService")
local RewardService = require(ServerScriptService.Services.RewardService)

local QuestService = {}

local function payout(player, reward)
	RewardService.give(player, reward)
end

local function grantRewards(player, quest)
	payout(player, quest.reward)
end

local function finishQuest(player, quest)
	grantRewards(player, quest)
end

function QuestService.validateStep(player, quest)
	finishQuest(player, quest)
end

function QuestService.complete(player, quest)
	QuestService.validateStep(player, quest)
end

return QuestService
