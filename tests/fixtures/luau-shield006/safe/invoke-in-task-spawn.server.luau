-- Safe: the invoke runs in a detached thread with a timeout, so the caller
-- never blocks; the answer is client data, so it is allow-listed against the
-- supported languages before use (a type check plus a length limit would not
-- be enough for SetAttribute, see luau-shield002).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetLanguage = ReplicatedStorage.Remotes.GetLanguage :: RemoteFunction
local TIMEOUT = 5
local SUPPORTED_LANGUAGES = { en = true, es = true, pt = true, fr = true, de = true }

Players.PlayerAdded:Connect(function(player: Player)
	local answered = false
	task.spawn(function()
		local ok, language = pcall(GetLanguage.InvokeClient, GetLanguage, player)
		answered = true
		if ok and typeof(language) == "string" and SUPPORTED_LANGUAGES[language] then
			player:SetAttribute("Language", language)
		end
	end)
	task.delay(TIMEOUT, function()
		if not answered then
			player:SetAttribute("Language", "en")
		end
	end)
end)
