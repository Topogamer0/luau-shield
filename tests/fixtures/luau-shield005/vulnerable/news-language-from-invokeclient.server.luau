--!strict
-- Vulnerable: the news panel is shown in the language of the player's UI.
-- When a player joins, the server asks the client which language its UI uses
-- (a RemoteFunction answered by a LocalScript), in a detached thread so that
-- a client that never answers blocks nothing, then fetches the news and sends
-- them to that player. What InvokeClient returns is client-controlled, just
-- like the arguments of a remote, and it is only type-checked before being
-- appended to the query string.
--
-- Exploit: the exploiter's auto-execute script sets OnClientInvoke before the
-- game's LocalScript does, returning "en&status=draft&limit=500". The server
-- requests unpublished drafts with its API key and sends them straight to
-- the exploiter.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetUiLanguage = ReplicatedStorage.Remotes.GetUiLanguage :: RemoteFunction
local NewsLoaded = ReplicatedStorage.Remotes.NewsLoaded :: RemoteEvent

local NEWS_URL = "https://content.example-studio.dev/v1/news"
local NEWS_HEADERS = { ["X-Api-Key"] = HttpService:GetSecret("content_api_key") }

Players.PlayerAdded:Connect(function(player: Player)
	task.spawn(function()
		local answered, language = pcall(function()
			return GetUiLanguage:InvokeClient(player)
		end)
		if not answered or typeof(language) ~= "string" then
			return
		end

		local url = `{NEWS_URL}?status=published&limit=5`
		if language ~= "en" then
			url ..= `&lang={language}`
		end
		local ok, body = pcall(function()
			return HttpService:GetAsync(url, false, NEWS_HEADERS) -- expect: luau-shield005
		end)
		if ok then
			NewsLoaded:FireClient(player, HttpService:JSONDecode(body))
		end
	end)
end)
