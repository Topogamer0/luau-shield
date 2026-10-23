-- Vulnerable (v0.2.0 review): `Plots.isOwner(player, player.Plot.Value)` holds for every player.
-- Plot building game: each player has an ObjectValue `player.Plot` that
-- points at their plot. `Plots.isOwner(player, plot)` checks that the player
-- owns the plot - every player owns one - so it is not an admin check: any
-- player sends a huge or negative income and prints coins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Plots = require(ServerScriptService.Plots)
local data = {}

ReplicatedStorage.Remotes.CollectIncome.OnServerEvent:Connect(function(player, income)
	local plot = player.Plot.Value
	if not Plots.isOwner(player, plot) then
		return
	end
	data[player].Coins += income -- expect: luau-shield001
end)
