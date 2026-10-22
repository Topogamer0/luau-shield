--!strict
-- Furniture placement: the client previews the furniture on the grid and
-- sends the furniture name and the position under the mouse. The handler
-- passes the position through two required modules: Grid.snap (shared) only
-- rounds it, and Plots.place (server) moves the model there. The finding is
-- reported at the sink, in Plots.luau.
--
-- Exploit: send a position inside another player's plot, inside a wall, or
-- 10,000 studs away: the furniture lands there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Grid = require(ReplicatedStorage.Shared.Grid)
local Plots = require(script.Parent.Plots)

local PlaceFurniture = ReplicatedStorage.Remotes.PlaceFurniture :: RemoteEvent

PlaceFurniture.OnServerEvent:Connect(function(player: Player, furnitureName: string, position: Vector3)
	local plot = Plots.getPlot(player)
	if not plot or typeof(position) ~= "Vector3" then
		return
	end

	local model = Plots.findFurniture(plot, furnitureName)
	if not model then
		return
	end

	Plots.place(model, Grid.snap(position))
end)
