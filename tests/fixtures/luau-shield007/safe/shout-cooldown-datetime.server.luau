--!strict
-- Safe: the cross-server shout keeps a 30-second per-player cooldown measured
-- with DateTime.now(), checked before any TextService or MessagingService
-- request.
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local SHOUT_COOLDOWN_MS = 30_000
local Shout = ReplicatedStorage.Remotes.Shout :: RemoteEvent
local lastShout: { [Player]: number } = {}

Shout.OnServerEvent:Connect(function(player: Player, message: unknown)
	local now = DateTime.now().UnixTimestampMillis
	if now - (lastShout[player] or 0) < SHOUT_COOLDOWN_MS then
		return
	end
	if typeof(message) ~= "string" or #message == 0 or #message > 120 then
		return
	end
	lastShout[player] = now
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(message, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		return
	end
	MessagingService:PublishAsync("Shouts", { from = player.Name, text = filtered })
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastShout[player] = nil
end)
