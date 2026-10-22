-- Safe: in-game report button (twin of the vulnerable report-discord-webhook
-- entry). The reason must be a string of at most 200 characters, each
-- player can send one report per minute, and the webhook payload disables
-- every mention, so "@everyone" in a reason is shown as plain text.
-- (The webhook URL is in a server Script, so it is not a luau-shield008 finding.)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReportPlayer = ReplicatedStorage.Remotes.ReportPlayer :: RemoteEvent

local REPORT_WEBHOOK = "https://discord.com/api/webhooks/1187654321098765432/fixtureTokenNotReal_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789-abcdefghij"
local MAX_REASON_LENGTH = 200
local REPORT_COOLDOWN = 60

local lastReport: { [Player]: number } = {}

ReportPlayer.OnServerEvent:Connect(function(player: Player, targetUserId: number, reason: string)
	local now = os.clock()
	if now - (lastReport[player] or -REPORT_COOLDOWN) < REPORT_COOLDOWN then
		return
	end
	if typeof(targetUserId) ~= "number" or typeof(reason) ~= "string" or #reason > MAX_REASON_LENGTH then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	lastReport[player] = now

	local message = `**Report** from {player.Name} ({player.UserId}) about {target.Name} ({target.UserId}): {reason}`
	local payload = HttpService:JSONEncode({ content = message, allowed_mentions = { parse = {} } })
	HttpService:PostAsync(REPORT_WEBHOOK, payload)
end)
