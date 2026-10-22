--!strict
-- Safe: the news panel in the language of the player's UI (twin of the
-- vulnerable news-language-from-invokeclient entry). The client reports its
-- UI language once through a RemoteEvent, instead of the server waiting on
-- InvokeClient, and the server only uses it if table.find locates it in its
-- own list of translated languages. The `loaded` lock lets each player load
-- the news once.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReportUiLanguage = ReplicatedStorage.Remotes.ReportUiLanguage :: RemoteEvent
local NewsLoaded = ReplicatedStorage.Remotes.NewsLoaded :: RemoteEvent

local NEWS_URL = "https://content.example-studio.dev/v1/news"
local NEWS_HEADERS = { ["X-Api-Key"] = HttpService:GetSecret("content_api_key") }
local TRANSLATED = { "en", "es", "pt", "fr", "de", "it", "ja", "ko" }

local loaded: { [Player]: boolean } = {}

ReportUiLanguage.OnServerEvent:Connect(function(player: Player, language: unknown)
	if loaded[player] then
		return
	end
	loaded[player] = true
	if not table.find(TRANSLATED, language) then
		return
	end

	local url = `{NEWS_URL}?status=published&limit=5`
	if language ~= "en" then
		url ..= `&lang={language}`
	end
	local ok, body = pcall(function()
		return HttpService:GetAsync(url, false, NEWS_HEADERS)
	end)
	if ok then
		NewsLoaded:FireClient(player, HttpService:JSONDecode(body))
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	loaded[player] = nil
end)
