-- Vulnerable (v0.2.0 review): a callback first met inside a summary must still be analysed for the handler that reaches it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local QuestService = require(ServerScriptService.Services.QuestService)

ReplicatedStorage.Remotes.CompleteQuest.OnServerEvent:Connect(function(player, quest)
	QuestService.complete(player, quest)
end)
