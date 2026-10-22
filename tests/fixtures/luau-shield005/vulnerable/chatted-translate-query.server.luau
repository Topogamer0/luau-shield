-- Vulnerable: live chat translation. Every chat message is appended,
-- unencoded, to the query string of a translation API.
--
-- Exploit: no remote is needed, chatting is enough. A message such as
-- "hi&model=premium-xl&max_chars=1000000" adds query parameters billed to
-- the game's API key, and messages containing "#", "?" or "/" rewrite the
-- request. Chatted fires for every message, so spamming the chat also
-- exhausts the server's HttpService budget.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatTranslated = ReplicatedStorage.Remotes.ChatTranslated :: RemoteEvent

local TRANSLATE_URL = "https://translate.example-studio.dev/v1/translate"
local TRANSLATE_KEY = HttpService:GetSecret("translate_api_key")

local function translate(text: string, targetLanguage: string): string?
	local url = TRANSLATE_URL .. "?target=" .. targetLanguage .. "&q=" .. text
	local ok, response = pcall(function()
		return HttpService:GetAsync(url, false, { ["X-Api-Key"] = TRANSLATE_KEY }) -- expect: luau-shield005
	end)
	if not ok then
		return nil
	end
	return HttpService:JSONDecode(response).translation
end

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(message: string)
		local translated = translate(message, "en")
		if translated then
			ChatTranslated:FireAllClients(player.UserId, translated)
		end
	end)
end)
