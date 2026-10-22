--!strict
-- Server-side plot helpers (ServerScriptService.Plots).

local Plots = {}

function Plots.getPlot(player: Player): Model?
	local plot = workspace.Plots:FindFirstChild(player.Name)
	return if plot and plot:IsA("Model") then plot else nil
end

function Plots.findFurniture(plot: Model, name: string): Model?
	local folder = plot:FindFirstChild("Furniture")
	local model = if folder then folder:FindFirstChild(name) else nil
	return if model and model:IsA("Model") then model else nil
end

-- Callers must pass a position that was checked with Grid.isInsidePlot.
function Plots.place(model: Model, position: Vector3)
	model:MoveTo(position)
end

return Plots
