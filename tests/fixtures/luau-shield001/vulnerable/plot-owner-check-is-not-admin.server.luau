-- Vulnerable: `isOwner(player, plot)` only proves that the player owns the
-- plot; it is not a permission check, so the client's `income` still needs
-- validating. A plot owner can set any income and print coins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Plots = require(ServerScriptService.Plots)
local data = {}

ReplicatedStorage.Remotes.CollectIncome.OnServerEvent:Connect(function(player, plotId, income)
	local plot = Plots.get(plotId)
	if not plot or not Plots.isOwner(player, plot) then
		return
	end
	data[player].Coins += income -- expect: luau-shield001
end)
