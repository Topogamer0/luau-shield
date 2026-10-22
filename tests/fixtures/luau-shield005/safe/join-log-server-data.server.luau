-- Safe, looks scary: a moderation log that posts to a Discord webhook when a
-- very new account joins (possible alt of a banned player). Everything in
-- the request comes from the server: the player's name, id and account age
-- are set by Roblox, not sent through a remote. The webhook URL lives in a
-- server Script, whose source never reaches clients, so it is not a luau-shield008
-- finding either.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local MOD_LOG_WEBHOOK = "https://discord.com/api/webhooks/1187654321098765432/fixtureTokenNotReal_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789-abcdefghij"
local NEW_ACCOUNT_DAYS = 3

local function postJoinAlert(player: Player)
	local payload = HttpService:JSONEncode({
		username = "Join log",
		content = `New account joined: **{player.Name}** (@{player.DisplayName}, id {player.UserId}), {player.AccountAge} day(s) old, server {game.JobId}`,
		allowed_mentions = { parse = {} },
	})
	local ok, err = pcall(function()
		HttpService:PostAsync(MOD_LOG_WEBHOOK, payload)
	end)
	if not ok then
		warn(`Join log failed: {err}`)
	end
end

Players.PlayerAdded:Connect(function(player: Player)
	if player.AccountAge < NEW_ACCOUNT_DAYS then
		task.spawn(postJoinAlert, player)
	end
end)
