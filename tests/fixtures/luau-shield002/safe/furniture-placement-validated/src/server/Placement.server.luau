--!strict
-- Furniture placement, fixed: the snapped position is validated with
-- Grid.isInsidePlot (a function of a required shared module, analysed
-- interprocedurally) before it reaches Plots.place. Validation happens on the
-- value that is actually used: snapping AFTER the check would produce a new,
-- unchecked value.

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

	local target = Grid.snap(position)
	if not Grid.isInsidePlot(target, plot:GetPivot().Position) then
		return
	end

	Plots.place(model, target)
end)
