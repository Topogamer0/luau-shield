--!strict
-- Vulnerable: private-server owners can connect their own Discord webhook to
-- get the server's kill feed. The settings panel has a "Send test message"
-- button: the owner pastes a webhook URL and the server posts a test message
-- to it. The URL is "validated" with a plain substring search, which only
-- proves that "discord.com/api/webhooks/" appears somewhere in it.
--
-- Exploit: anyone who owns a private server (free or a few Robux in many
-- games) fires TestWebhook with "https://attacker.example/x?discord.com/api/webhooks/"
-- and the game server sends POST requests to any host and path they choose.
-- The game becomes an anonymous request relay against third-party services,
-- and the abuse is traced back to the game, not to the exploiter.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestWebhook = ReplicatedStorage.Remotes.TestWebhook :: RemoteEvent

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

	if typeof(webhookUrl) ~= "string" or not webhookUrl:find("discord.com/api/webhooks/", 1, true) then
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
		return HttpService:RequestAsync(request) -- expect: luau-shield005
	end)
	if not ok or not response.Success then
		warn(`Webhook test failed for {player.Name}`)
	end
end)
