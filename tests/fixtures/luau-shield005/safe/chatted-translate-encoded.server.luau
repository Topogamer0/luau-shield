-- Safe: live chat translation (twin of the vulnerable
-- chatted-translate-query entry). The chat message is passed through
-- HttpService:UrlEncode before it is appended to the query string, so it
-- can only ever be the value of the "q" parameter. Long messages are not
-- translated at all.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatTranslated = ReplicatedStorage.Remotes.ChatTranslated :: RemoteEvent

local TRANSLATE_URL = "https://translate.example-studio.dev/v1/translate"
local TRANSLATE_KEY = HttpService:GetSecret("translate_api_key")
local MAX_MESSAGE_LENGTH = 200

local function translate(text: string, targetLanguage: string): string?
	local url = TRANSLATE_URL .. "?target=" .. targetLanguage .. "&q=" .. HttpService:UrlEncode(text)
	local ok, response = pcall(function()
		return HttpService:GetAsync(url, false, { ["X-Api-Key"] = TRANSLATE_KEY })
	end)
	if not ok then
		return nil
	end
	return HttpService:JSONDecode(response).translation
end

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(message: string)
		if #message > MAX_MESSAGE_LENGTH then
			return
		end
		local translated = translate(message, "en")
		if translated then
			ChatTranslated:FireAllClients(player.UserId, translated)
		end
	end)
end)
