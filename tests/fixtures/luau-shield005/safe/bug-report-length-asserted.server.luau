--!strict
-- Safe: the bug report form (twin of the vulnerable bug-report-length-warn-only
-- entry). Both client values are checked with assert, which stops the handler
-- when a check fails: the category must be one of the server's categories,
-- and the description a string of at most 1000 characters. JSONEncode escapes
-- quotes and newlines, so a short string cannot add fields to the issue.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SubmitBugReport = ReplicatedStorage.Remotes.SubmitBugReport :: RemoteEvent

local TRACKER_URL = "https://tracker.example-studio.dev/api/issues"
local TRACKER_HEADERS = { Authorization = HttpService:GetSecret("tracker_token"):AddPrefix("Bearer ") }
local CATEGORIES: { [string]: boolean } = { Gameplay = true, UI = true, Performance = true, Other = true }
local MAX_DESCRIPTION = 1000
local REPORT_COOLDOWN = 30

local lastReport: { [Player]: number } = {}

local function onBugReport(player: Player, category: unknown, description: unknown)
	local now = os.clock()
	if now - (lastReport[player] or -REPORT_COOLDOWN) < REPORT_COOLDOWN then
		return
	end
	lastReport[player] = now
	assert(typeof(category) == "string" and CATEGORIES[category], "unknown bug report category")
	assert(typeof(description) == "string" and #description <= MAX_DESCRIPTION, "bug report too long")

	local issue = {
		title = `[{category}] In-game report from {player.Name}`,
		body = description,
		labels = { "in-game", category },
		placeVersion = game.PlaceVersion,
	}
	HttpService:PostAsync(TRACKER_URL, HttpService:JSONEncode(issue), Enum.HttpContentType.ApplicationJson, false, TRACKER_HEADERS)
end

SubmitBugReport.OnServerEvent:Connect(onBugReport)
