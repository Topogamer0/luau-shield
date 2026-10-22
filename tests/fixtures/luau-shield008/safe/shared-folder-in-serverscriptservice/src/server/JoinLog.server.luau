--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Webhooks = require(script.Parent.Shared.Webhooks)

Players.PlayerAdded:Connect(function(player: Player)
	local body = HttpService:JSONEncode({ content = `{player.Name} ({player.UserId}) joined` })
	HttpService:PostAsync(Webhooks.ModLog, body)
end)
