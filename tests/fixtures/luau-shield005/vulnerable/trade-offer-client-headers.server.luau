--!strict
-- Vulnerable: cross-server trading. Offers are stored by an external trading
-- backend. The client may attach "extra" headers (meant for a support trace
-- id), and the server copies them into the request after its own headers.
--
-- Exploit: the backend trusts the game server and identifies the player with
-- the X-Player-Id header. SubmitOffer:FireServer("Sword", { ["X-Player-Id"] =
-- "261" }) overrides it, so the exploiter creates offers in the name of any
-- other player; overriding X-Api-Key or Content-Type breaks or reroutes the
-- request.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SubmitOffer = ReplicatedStorage.Remotes.SubmitOffer :: RemoteEvent

local OFFERS_URL = "https://trading.example-studio.dev/v1/offers"
local API_KEY = HttpService:GetSecret("trading_api_key")
local OFFER_COOLDOWN = 5
local OFFERABLE: { [string]: boolean } = { Sword = true, Shield = true, Lantern = true }

local lastOffer: { [Player]: number } = {}

SubmitOffer.OnServerEvent:Connect(function(player: Player, itemId: string, extraHeaders: { [string]: string }?)
	local now = os.clock()
	if now - (lastOffer[player] or 0) < OFFER_COOLDOWN then
		return
	end
	lastOffer[player] = now
	if typeof(itemId) ~= "string" or not OFFERABLE[itemId] then
		return
	end

	local headers: { [string]: any } = {
		["Content-Type"] = "application/json",
		["X-Api-Key"] = API_KEY,
		["X-Player-Id"] = tostring(player.UserId),
	}
	if typeof(extraHeaders) == "table" then
		for name, value in extraHeaders do
			headers[name] = value
		end
	end

	local request = {
		Url = OFFERS_URL,
		Method = "POST",
		Headers = headers,
		Body = HttpService:JSONEncode({ item = itemId }),
	}
	local response = HttpService:RequestAsync(request) -- expect: luau-shield005
	if not response.Success then
		warn(`Trade offer failed: {response.StatusCode}`)
	end
end)
