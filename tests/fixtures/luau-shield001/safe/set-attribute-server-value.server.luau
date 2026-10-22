--!strict
-- Safe: coin pickups stored in a "Coins" attribute (twin of the vulnerable
-- set-attribute-coins entry). Coins are spawned by the server, which keeps
-- their value; the client only says which pickup it touched. The id selects a
-- server record and the player must be next to it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinTouched = ReplicatedStorage.Remotes.CoinTouched :: RemoteEvent

local PICKUP_RANGE = 12

type Pickup = { part: BasePart, value: number }

local pickups: { [string]: Pickup } = {}

local function onCoinTouched(player: Player, pickupId: string)
	local pickup = pickups[pickupId]
	if not pickup or not player.Character then
		return
	end
	if player:DistanceFromCharacter(pickup.part.Position) > PICKUP_RANGE then
		return
	end
	pickups[pickupId] = nil
	pickup.part:Destroy()

	local current = player:GetAttribute("Coins") or 0
	player:SetAttribute("Coins", current + pickup.value)
end

CoinTouched.OnServerEvent:Connect(onCoinTouched)
