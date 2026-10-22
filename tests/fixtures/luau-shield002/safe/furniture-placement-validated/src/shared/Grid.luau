--!strict
-- Grid helpers shared by the placement preview (client) and the server.
-- isInsidePlot is a validation function: luau-shield analyses it and learns
-- that, when it returns true, `position` is a Vector3 within PLOT_RADIUS
-- studs of the plot centre.

local Grid = {}

export type Cell = Vector3

Grid.CELL_SIZE = 4

local PLOT_RADIUS = 48

-- Rounds a position to the centre of the nearest grid cell.
function Grid.snap(position: Vector3): Cell
	local cell = Grid.CELL_SIZE
	return Vector3.new(
		math.floor(position.X / cell + 0.5) * cell,
		position.Y,
		math.floor(position.Z / cell + 0.5) * cell
	)
end

function Grid.isInsidePlot(position: unknown, plotCenter: Vector3): boolean
	return typeof(position) == "Vector3" and (position - plotCenter).Magnitude <= PLOT_RADIUS
end

return Grid
