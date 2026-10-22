-- Safe: the invoke runs in a detached thread with a timeout, so the caller
-- never blocks; the answer is type-checked before use.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GetLanguage = ReplicatedStorage.Remotes.GetLanguage :: RemoteFunction
local TIMEOUT = 5

Players.PlayerAdded:Connect(function(player: Player)
	local answered = false
	task.spawn(function()
		local ok, language = pcall(GetLanguage.InvokeClient, GetLanguage, player)
		answered = true
		if ok and typeof(language) == "string" and #language <= 8 then
			player:SetAttribute("Language", language)
		end
	end)
	task.delay(TIMEOUT, function()
		if not answered then
			player:SetAttribute("Language", "en")
		end
	end)
end)
