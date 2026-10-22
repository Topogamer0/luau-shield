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

-- Trusts its caller: whatever position it receives is where the model goes.
function Plots.place(model: Model, position: Vector3)
	model:MoveTo(position) -- expect: luau-shield002
end

return Plots
