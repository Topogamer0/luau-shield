-- Vulnerable: custom analytics. The client reports UI events (shop opened,
-- tutorial step reached) with a table of extra fields, and the server
-- forwards them to the studio's analytics pipeline. The event name is
-- allow-listed, but the extra fields are JSON-encoded into the body as they
-- arrived. A per-player lock keeps the remote from being spammed.
--
-- Exploit: TrackEvent:FireServer("ShopOpened", { revenue = 1e9, userId = 1,
-- padding = string.rep("x", 400000) }) injects arbitrary fields into the
-- pipeline: fake purchases and fake players poison the dashboards the team
-- uses for decisions, and huge payloads inflate the analytics bill.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HttpService = game.HttpService
local TrackEvent = ReplicatedStorage.Remotes.TrackEvent :: RemoteEvent

local ANALYTICS_URL = "https://analytics.example-studio.dev/v1/events"
local EVENTS = { ShopOpened = true, TutorialStep = true, QuestAccepted = true }

local busy: { [Player]: boolean } = {}

local function onTrackEvent(player: Player, eventName: string, fields: { [string]: any })
	if busy[player] then
		return
	end
	if typeof(eventName) ~= "string" or not EVENTS[eventName] then
		return
	end
	busy[player] = true
	task.delay(2, function()
		busy[player] = nil
	end)

	local payload = {
		event = eventName,
		userId = player.UserId,
		sessionId = game.JobId,
		fields = fields,
	}
	HttpService:PostAsync(ANALYTICS_URL, HttpService:JSONEncode(payload), Enum.HttpContentType.ApplicationJson) -- expect: luau-shield005
end

TrackEvent.OnServerEvent:Connect(onTrackEvent)
