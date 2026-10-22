--!strict
-- Safe, looks scary: player feedback is forwarded to the studio's feedback
-- tracker with no explicit length limit. The text goes through Roblox text
-- filtering first (FilterStringAsync + GetNonChatStringForBroadcastAsync),
-- and only the filtered string is put in the body. Each player can send one
-- message every 30 seconds.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local SendFeedback = ReplicatedStorage.Remotes.SendFeedback :: RemoteEvent

local FEEDBACK_URL = "https://feedback.example-studio.dev/v1/messages"
local FEEDBACK_HEADERS = { ["X-Api-Key"] = HttpService:GetSecret("feedback_api_key") }
local FEEDBACK_COOLDOWN = 30

local lastFeedback: { [Player]: number } = {}

local function filterForBroadcast(text: string, fromUserId: number): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, fromUserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok then result else nil
end

SendFeedback.OnServerEvent:Connect(function(player: Player, text: string)
	local now = os.clock()
	if now - (lastFeedback[player] or -FEEDBACK_COOLDOWN) < FEEDBACK_COOLDOWN then
		return
	end
	if typeof(text) ~= "string" then
		return
	end
	lastFeedback[player] = now

	local filtered = filterForBroadcast(text, player.UserId)
	if not filtered then
		return
	end
	local body = HttpService:JSONEncode({ userId = player.UserId, placeVersion = game.PlaceVersion, text = filtered })
	HttpService:PostAsync(FEEDBACK_URL, body, Enum.HttpContentType.ApplicationJson, false, FEEDBACK_HEADERS)
end)
