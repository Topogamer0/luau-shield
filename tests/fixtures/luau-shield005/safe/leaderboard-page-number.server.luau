--!strict
-- Safe, looks scary: the global leaderboard is paged through the studio's
-- stats API, and the page number sent by the client goes into the query
-- string with no bounds at all. It is enough that it is a number: a number
-- interpolated into a string only produces digits, ".", "-", "e", "+", "inf"
-- or "nan", never "&", "/", "?" or "#", so it cannot change the request.
-- A page that does not exist simply comes back empty.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetLeaderboardPage = ReplicatedStorage.Remotes.GetLeaderboardPage :: RemoteFunction

local STATS_API = "https://stats.example-studio.dev/v1/leaderboards/season-7"
local STATS_HEADERS = { ["X-Api-Key"] = HttpService:GetSecret("stats_api_key") }
local PAGE_COOLDOWN = 0.5

local lastPage: { [Player]: number } = {}

GetLeaderboardPage.OnServerInvoke = function(player: Player, page: unknown): { any }?
	local now = os.clock()
	if now - (lastPage[player] or 0) < PAGE_COOLDOWN then
		return nil
	end
	lastPage[player] = now
	if typeof(page) ~= "number" then
		return nil
	end

	local ok, body = pcall(function()
		return HttpService:GetAsync(`{STATS_API}/entries?pageSize=25&page={page}`, false, STATS_HEADERS)
	end)
	return if ok then HttpService:JSONDecode(body).entries else nil
end
