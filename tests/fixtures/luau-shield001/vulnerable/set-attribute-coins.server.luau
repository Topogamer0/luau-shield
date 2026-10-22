-- Vulnerable: coins are kept in a "Coins" attribute on the Player (the HUD
-- listens to it and the data module saves it on leave). The client tells the
-- server how much the coin it touched was worth.
--
-- Exploit: fire CoinTouched with 1e9 instead of the 5 a real coin is worth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinTouched = ReplicatedStorage.Remotes.CoinTouched :: RemoteEvent

local function onCoinTouched(player: Player, coinValue: number)
	local current = player:GetAttribute("Coins") or 0
	player:SetAttribute("Coins", current + coinValue) -- expect: luau-shield001
end

CoinTouched.OnServerEvent:Connect(onCoinTouched)
