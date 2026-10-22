-- Vulnerable: in-game report button. The reason typed by the player is
-- forwarded to the moderators' Discord channel through a webhook. The reason
-- is only type-checked: no length limit, no filtering, and the remote has no
-- rate limit either (luau-shield007).
--
-- Exploit: an exploiter fires ReportPlayer in a loop with 2000-character
-- reasons full of "@everyone" pings, scam links and slurs. The moderators'
-- channel is flooded, Discord rate-limits and then deletes the webhook, and
-- the game can be reported for the content it relayed. The loop also uses up
-- the server's HttpService budget.
-- (The webhook URL is in a server Script, so it is not a luau-shield008 finding.)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReportPlayer = ReplicatedStorage.Remotes.ReportPlayer :: RemoteEvent

local REPORT_WEBHOOK = "https://discord.com/api/webhooks/1187654321098765432/fixtureTokenNotReal_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789-abcdefghij"

ReportPlayer.OnServerEvent:Connect(function(player: Player, targetUserId: number, reason: string) -- expect: luau-shield007
	if typeof(targetUserId) ~= "number" or typeof(reason) ~= "string" then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end

	local message = `**Report** from {player.Name} ({player.UserId}) about {target.Name} ({target.UserId}): {reason}`
	HttpService:PostAsync(REPORT_WEBHOOK, HttpService:JSONEncode({ content = message })) -- expect: luau-shield005
end)
