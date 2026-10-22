--!strict
-- Safe: "Send test message" for the private-server kill feed (twin of the
-- vulnerable private-server-webhook-substring-check entry). The webhook URL
-- must match a pattern anchored at both ends: the scheme and host are fixed,
-- the id is digits only and the token is letters, digits, "_" or "-". Nothing
-- can come before the host or after the token, so the only requests the
-- client can trigger are posts to a Discord webhook, once every 10 seconds.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestWebhook = ReplicatedStorage.Remotes.TestWebhook :: RemoteEvent

local WEBHOOK_PATTERN = "^https://discord%.com/api/webhooks/%d+/[%w_%-]+$"
local TEST_COOLDOWN = 10
local lastTest: { [Player]: number } = {}

TestWebhook.OnServerEvent:Connect(function(player: Player, webhookUrl: unknown)
	if game.PrivateServerOwnerId ~= player.UserId then
		return
	end
	local now = os.clock()
	if now - (lastTest[player] or -TEST_COOLDOWN) < TEST_COOLDOWN then
		return
	end
	lastTest[player] = now

	if typeof(webhookUrl) ~= "string" or not webhookUrl:match(WEBHOOK_PATTERN) then
		return
	end

	local request = {
		Url = webhookUrl,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = HttpService:JSONEncode({
			content = `Kill feed connected to the private server of {player.Name}.`,
			allowed_mentions = { parse = {} },
		}),
	}
	local ok, response = pcall(function()
		return HttpService:RequestAsync(request)
	end)
	if not ok or not response.Success then
		warn(`Webhook test failed for {player.Name}`)
	end
end)
