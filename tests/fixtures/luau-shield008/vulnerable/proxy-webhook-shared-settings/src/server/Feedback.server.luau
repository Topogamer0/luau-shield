--!strict
-- The server side is written correctly (type and length check, cooldown): the
-- problem is only where the webhook URL is stored.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)

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
	HttpService:PostAsync(Settings.FeedbackWebhook, body)
end)
