-- Vulnerable: suggestion box. Suggestions are relayed to the community
-- Discord through a webhook, using the common
-- pcall(HttpService.PostAsync, HttpService, ...) form so that a failed request
-- does not error. That is still a call to HttpService:PostAsync, and the
-- suggestion is only type-checked: no length limit, no filtering, and Discord
-- pings are left enabled.
--
-- Exploit: SendSuggestion:FireServer(string.rep("@everyone free robux at
-- scam.example ", 50)) once a minute from a few accounts pings the whole
-- community server with scam links. Discord deletes the webhook, and the game
-- is held responsible for what it relayed.
-- (The webhook URL is in a server Script, so it is not a luau-shield008 finding.)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SendSuggestion = ReplicatedStorage.Remotes.SendSuggestion :: RemoteEvent

local SUGGESTIONS_WEBHOOK = "https://discord.com/api/webhooks/1187654321098765432/fixtureTokenNotReal_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789-abcdefghij"
local SUGGESTION_COOLDOWN = 60

local lastSuggestion: { [number]: number } = {}

SendSuggestion.OnServerEvent:Connect(function(player: Player, suggestion: string)
	local now = os.clock()
	if now - (lastSuggestion[player.UserId] or -SUGGESTION_COOLDOWN) < SUGGESTION_COOLDOWN then
		return
	end
	if typeof(suggestion) ~= "string" then
		return
	end
	lastSuggestion[player.UserId] = now

	local payload = HttpService:JSONEncode({ username = player.Name, content = suggestion })
	local ok, err = pcall(HttpService.PostAsync, HttpService, SUGGESTIONS_WEBHOOK, payload) -- expect: luau-shield005
	if not ok then
		warn(`Suggestion from {player.Name} not delivered: {err}`)
	end
end)
