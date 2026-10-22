--!strict
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local Webhooks = require(ServerStorage.Secrets.Webhooks)

local SendFeedback = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SendFeedback") :: RemoteEvent
local lastSent: { [Player]: number } = {}

SendFeedback.OnServerEvent:Connect(function(player: Player, text: unknown)
	local now = os.clock()
	if now - (lastSent[player] or -math.huge) < Settings.FeedbackCooldown then
		return
	end
	if typeof(text) ~= "string" or #text > Settings.MaxFeedbackLength then
		return
	end
	lastSent[player] = now
	local body = HttpService:JSONEncode({ content = `{player.Name}: {text}` })
	HttpService:PostAsync(Webhooks.Feedback, body)
end)
