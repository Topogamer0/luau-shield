-- Vulnerable: each "I found a bug" click posts to the team webhook. The body
-- only contains server data, but spamming the remote exhausts the HttpService
-- budget and gets the webhook rate-limited or banned.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WEBHOOK = HttpService:GetSecret("bug_webhook")

ReplicatedStorage.Remotes.FoundBug.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local body = HttpService:JSONEncode({
		content = `{player.Name} ({player.UserId}) reported a bug in {game.PlaceId}`,
	})
	HttpService:PostAsync(WEBHOOK, body)
end)
