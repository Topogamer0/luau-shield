--!strict
-- Safe: cross-server trading (twin of the vulnerable
-- trade-offer-client-headers entry). The server builds every header itself.
-- The only header that depends on the client, X-Client-Platform, is taken
-- from an allow-list: t.keyOf accepts only the keys of PLATFORMS, and
-- t.tuple applies one checker to each argument.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local SubmitOffer = ReplicatedStorage.Remotes.SubmitOffer :: RemoteEvent

local OFFERS_URL = "https://trading.example-studio.dev/v1/offers"
local API_KEY = HttpService:GetSecret("trading_api_key")
local OFFER_COOLDOWN = 5
local OFFERABLE: { [string]: boolean } = { Sword = true, Shield = true, Lantern = true }
local PLATFORMS: { [string]: boolean } = { Desktop = true, Phone = true, Tablet = true, Console = true, VR = true }

local checkOffer = t.tuple(t.keyOf(OFFERABLE), t.keyOf(PLATFORMS))

local lastOffer: { [Player]: number } = {}

SubmitOffer.OnServerEvent:Connect(function(player: Player, itemId: string, platform: string)
	local now = os.clock()
	if now - (lastOffer[player] or 0) < OFFER_COOLDOWN then
		return
	end
	lastOffer[player] = now
	if not checkOffer(itemId, platform) then
		return
	end

	local request = {
		Url = OFFERS_URL,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["X-Api-Key"] = API_KEY,
			["X-Player-Id"] = tostring(player.UserId),
			["X-Client-Platform"] = platform,
		},
		Body = HttpService:JSONEncode({ item = itemId }),
	}
	local response = HttpService:RequestAsync(request)
	if not response.Success then
		warn(`Trade offer failed: {response.StatusCode}`)
	end
end)
