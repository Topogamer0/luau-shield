-- Safe (looks scary): trade preview. The client sends the offer it is
-- building and the server answers with a preview that includes the trade
-- tax. `preview.Coins = offer.coins` writes a client value to a "Coins" field,
-- but `preview` is a table literal created in this function and sent back to
-- the same client: nothing reaches stats, saved data or a DataStore. The real
-- trade goes through a separate, validated handler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PreviewTrade = ReplicatedStorage.Remotes.PreviewTrade :: RemoteFunction

local TAX_RATE = 0.1

type Offer = { coins: number, gems: number }

PreviewTrade.OnServerInvoke = function(player: Player, offer: Offer)
	if typeof(offer) ~= "table" then
		return nil
	end

	local preview = { Coins = 0, Gems = 0, Tax = 0, From = player.Name }
	preview.Coins = offer.coins
	preview.Gems = offer.gems
	if typeof(offer.coins) == "number" then
		preview.Tax = math.ceil(offer.coins * TAX_RATE)
	end
	return preview
end
