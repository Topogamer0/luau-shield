--!strict
-- Sends gameplay analytics and bug reports to external services.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Analytics = {}

-- Records an event sent by the client UI. The event name becomes part of
-- the endpoint, e.g. POST /v1/events/shop_opened.
function Analytics.track(player: Player, eventName: string, properties: { [string]: any })
	local url = `{Config.AnalyticsUrl}/events/{eventName}?key={Config.AnalyticsApiKey}`
	local body = HttpService:JSONEncode({
		userId = player.UserId,
		properties = properties,
	})
	HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
end

-- Posts a bug report to the team's Discord channel.
function Analytics.reportBug(player: Player, category: string, text: string)
	local content = `**[{category}]** {player.Name} ({player.UserId}): {text}`
	local body = HttpService:JSONEncode({ content = content })
	HttpService:PostAsync(Config.BugReportWebhook, body, Enum.HttpContentType.ApplicationJson)
end

return Analytics
