-- Safe: promo codes checked by the studio's web service (twin of the
-- vulnerable redeem-code-unanchored-pattern entry). The pattern is anchored
-- at both ends, so the whole code is made of letters and digits: it cannot
-- contain "/", "?", "#" or "..", and string.format can only build the URL of
-- the redeem endpoint.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RedeemCode = ReplicatedStorage.Remotes.RedeemCode :: RemoteEvent
local RedeemResult = ReplicatedStorage.Remotes.RedeemResult :: RemoteEvent

local PROMO_API = "https://promo.example-studio.dev/v1"
local PROMO_HEADERS = { ["X-Api-Key"] = HttpService:GetSecret("promo_api_key") }
local REDEEM_COOLDOWN = 5

local redeemCooldown: { [Player]: number } = {}

RedeemCode.OnServerEvent:Connect(function(player: Player, code: string)
	local last = redeemCooldown[player]
	if last and os.clock() - last < REDEEM_COOLDOWN then
		return
	end
	redeemCooldown[player] = os.clock()

	if typeof(code) ~= "string" or #code > 20 or not code:match("^%w+$") then
		return
	end

	local url = string.format("%s/codes/%s/redeem", PROMO_API, code)
	local body = HttpService:JSONEncode({ userId = player.UserId })
	local ok = pcall(function()
		HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false, PROMO_HEADERS)
	end)
	RedeemResult:FireClient(player, ok)
end)
