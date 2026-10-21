--!strict
-- Sends gameplay analytics and bug reports to external services.
--
-- The bug report webhook URL and the analytics API key are experience
-- secrets (Creator Hub > Secrets store) read with HttpService:GetSecret.
-- They only exist on the server and never appear in replicated code.
-- Callers validate every client value before calling these functions.

local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local ANALYTICS_URL = "https://analytics.tycoonshop.example/v1"

local function getSecret(name: string): Secret?
	local ok, secret = pcall(function()
		return HttpService:GetSecret(name)
	end)
	if not ok then
		warn(`Secret "{name}" is not configured`)
		return nil
	end
	return secret
end

local analyticsKey = getSecret("analytics_api_key")
local bugReportWebhook = getSecret("bug_report_webhook")

-- Filters user text so it is safe to show to everyone.
local function filterForBroadcast(text: string, fromUserId: number): string?
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return nil
	end
	return filtered
end

local Analytics = {}

-- `eventName` comes from Config.AnalyticsEvents and `detail` is a short
-- string; the URL path is built by the server and URL-encoded.
function Analytics.track(player: Player, eventName: string, detail: string)
	if not analyticsKey then
		return
	end
	local ok, err = pcall(function()
		HttpService:RequestAsync({
			Url = `{ANALYTICS_URL}/events/{HttpService:UrlEncode(eventName)}`,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["X-Api-Key"] = analyticsKey,
			},
			Body = HttpService:JSONEncode({ userId = player.UserId, detail = detail }),
		})
	end)
	if not ok then
		warn(`Analytics request failed: {err}`)
	end
end

-- Posts a bug report to the team's Discord channel. `category` comes from
-- Config.BugCategories and `text` is length-limited by the caller; the text
-- is also filtered and mentions (@everyone) are disabled.
function Analytics.reportBug(player: Player, category: string, text: string)
	local filtered = filterForBroadcast(text, player.UserId)
	if not bugReportWebhook or not filtered then
		return
	end
	local ok, err = pcall(function()
		HttpService:RequestAsync({
			Url = bugReportWebhook,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				content = `**[{category}]** {player.Name} ({player.UserId}): {filtered}`,
				allowed_mentions = { parse = {} },
			}),
		})
	end)
	if not ok then
		warn(`Bug report failed: {err}`)
	end
end

return Analytics
