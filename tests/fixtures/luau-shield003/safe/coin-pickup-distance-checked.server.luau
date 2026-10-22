-- Coin pickups, fixed: on top of the tag check, the coin must be within
-- PICKUP_RANGE studs of the player's HumanoidRootPart. Firing the remote for
-- coins on the other side of the map does nothing.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectCoin = ReplicatedStorage.Remotes.CollectCoin :: RemoteEvent

local COIN_VALUE = 5
local PICKUP_RANGE = 10

CollectCoin.OnServerEvent:Connect(function(player: Player, coin: BasePart)
	if typeof(coin) ~= "Instance" or not CollectionService:HasTag(coin, "Coin") then
		return
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or (coin.Position - root.Position).Magnitude > PICKUP_RANGE then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = if leaderstats then leaderstats:FindFirstChild("Coins") :: IntValue? else nil
	if not coins then
		return
	end

	CollectionService:RemoveTag(coin, "Coin")
	coin:Destroy()
	coins.Value += COIN_VALUE
end)
