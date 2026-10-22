--!strict
-- Vulnerable: a cross-server "shout" filters the message and publishes it to
-- every server of the experience. Each request costs a TextService call and a
-- MessagingService publish, and the publish budget is shared by the whole
-- game: one exploiter spamming Shout silences every other cross-server
-- message (shouts, trade notices, server-list updates).
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shout = ReplicatedStorage.Remotes.Shout :: RemoteEvent

Shout.OnServerEvent:Connect(function(player: Player, message: unknown) -- expect: luau-shield007
	if typeof(message) ~= "string" or #message == 0 or #message > 120 then
		return
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(message, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return
	end
	MessagingService:PublishAsync("Shouts", { from = player.Name, text = filtered })
end)
