-- Vulnerable (v0.2.0 review): `plot:isOwner(player)` is about a plot, not a permission check.
-- Plot system: Plot objects are looked up by id; Plot:isOwner(player) compares plot.owner.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlotService = require(ServerScriptService.PlotService)
local data = {}

ReplicatedStorage.Remotes.SellCrops.OnServerEvent:Connect(function(player, plotId, earned)
	local plot = PlotService.getPlot(plotId)
	if not plot or not plot:isOwner(player) then
		return
	end
	data[player].Coins += earned -- expect: luau-shield001
end)
