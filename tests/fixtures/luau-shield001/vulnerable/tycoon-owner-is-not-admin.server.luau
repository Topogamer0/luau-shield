-- Vulnerable (v0.2.0 review): every player owns a tycoon; `isOwner` is not an admin check.
-- Tycoon kit: each tycoon has an Owner ObjectValue. Every player owns a
-- tycoon, so `isOwner` is not an admin check.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local tycoon = script.Parent
local data = {}

local function isOwner(player)
	return tycoon.Owner.Value == player
end

ReplicatedStorage.Remotes.BuyButton.OnServerEvent:Connect(function(player, price)
	if not isOwner(player) then
		return
	end
	data[player].Coins -= price -- expect: luau-shield001
end)
