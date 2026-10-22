-- Coin pickups: a LocalScript detects when the character touches a coin and
-- fires CollectCoin with it. The server only checks that the part is tagged
-- "Coin" with CollectionService. A tag says WHAT the part is, not WHERE it is
-- relative to the player.
--
-- Exploit: on the client, loop over CollectionService:GetTagged("Coin") and
-- fire CollectCoin for every coin on the map. All coins are collected from
-- spawn in one frame, every time they respawn: a perfect autofarm.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectCoin = ReplicatedStorage.Remotes.CollectCoin :: RemoteEvent

local COIN_VALUE = 5

CollectCoin.OnServerEvent:Connect(function(player: Player, coin: BasePart)
	if typeof(coin) ~= "Instance" or not CollectionService:HasTag(coin, "Coin") then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = if leaderstats then leaderstats:FindFirstChild("Coins") :: IntValue? else nil
	if not coins then
		return
	end

	CollectionService:RemoveTag(coin, "Coin") -- expect: luau-shield003
	coin:Destroy()
	coins.Value += COIN_VALUE
end)
