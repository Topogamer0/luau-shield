--!strict
-- Safe, looks scary: performance telemetry. The client reports its frame
-- rate and settings over an UnreliableRemoteEvent, and the server forwards
-- them to an analytics service at most once per minute per player. Every
-- client value in the body is checked: the frame rate is converted with
-- tonumber, the platform is allow-listed and the flag is a type-checked
-- boolean.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReportMetrics = ReplicatedStorage.Remotes.ReportMetrics :: UnreliableRemoteEvent

local ANALYTICS_URL = "https://analytics.example-studio.dev/v1/frames"
local REPORT_INTERVAL = 60
local PLATFORMS: { [string]: boolean } = { Desktop = true, Phone = true, Tablet = true, Console = true, VR = true }

local lastReport: { [Player]: number } = {}

ReportMetrics.OnServerEvent:Connect(function(player: Player, fps: unknown, platform: unknown, reducedMotion: unknown)
	local now = os.clock()
	if now - (lastReport[player] or -REPORT_INTERVAL) < REPORT_INTERVAL then
		return
	end

	local frameRate = tonumber(fps)
	if not frameRate or typeof(platform) ~= "string" or not PLATFORMS[platform] then
		return
	end
	if typeof(reducedMotion) ~= "boolean" then
		return
	end
	lastReport[player] = now

	local body = HttpService:JSONEncode({
		userId = player.UserId,
		fps = frameRate,
		platform = platform,
		reducedMotion = reducedMotion,
	})
	HttpService:PostAsync(ANALYTICS_URL, body, Enum.HttpContentType.ApplicationJson)
end)
