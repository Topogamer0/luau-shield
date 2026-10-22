-- Vulnerable: promo codes are checked by the studio's web service. The
-- developer "validates" the code with a pattern, but the pattern is not
-- anchored: it only proves that the string contains a letter or a digit
-- somewhere. string.format builds the URL from the raw code.
--
-- Exploit: RedeemCode:FireServer("x/../../admin/codes?value=1000000#")
-- passes the check and turns the redeem call into an authenticated POST to
-- the code administration endpoint, with the rest of the URL cut off by "#".

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

	if typeof(code) ~= "string" or #code > 64 or not code:match("%w+") then
		return
	end

	local url = string.format("%s/codes/%s/redeem", PROMO_API, code)
	local body = HttpService:JSONEncode({ userId = player.UserId })
	local ok = pcall(function()
		HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false, PROMO_HEADERS) -- expect: luau-shield005
	end)
	RedeemResult:FireClient(player, ok)
end)
