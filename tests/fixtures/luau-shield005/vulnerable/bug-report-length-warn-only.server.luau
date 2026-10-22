--!strict
-- Vulnerable: the bug report form creates an issue in the studio's tracker.
-- The category is allow-listed and the remote is rate-limited, and there is
-- even a length check on the description, but it only logs a warning: it does
-- not stop the handler, so an oversized description is posted anyway.
--
-- Exploit: SubmitBugReport:FireServer("Other", string.rep("A", 100000)) from a
-- few accounts every 30 seconds creates issues a hundred times larger than
-- the form allows: they bury the real reports and fill the storage quota of
-- the tracker plan.

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
	if typeof(category) ~= "string" or not CATEGORIES[category] or typeof(description) ~= "string" then
		return
	end
	if #description > MAX_DESCRIPTION then
		warn(`{player.Name} sent a bug report of {#description} characters`)
	end
	lastReport[player] = now

	local issue = {
		title = `[{category}] In-game report from {player.Name}`,
		body = description,
		labels = { "in-game", category },
		placeVersion = game.PlaceVersion,
	}
	HttpService:PostAsync(TRACKER_URL, HttpService:JSONEncode(issue), Enum.HttpContentType.ApplicationJson, false, TRACKER_HEADERS) -- expect: luau-shield005
end

SubmitBugReport.OnServerEvent:Connect(onBugReport)
