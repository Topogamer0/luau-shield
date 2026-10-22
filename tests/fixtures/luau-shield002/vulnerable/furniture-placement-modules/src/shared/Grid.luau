--!strict
-- Grid helpers shared by the placement preview (client) and the server.

local Grid = {}

Grid.CELL_SIZE = 4

-- Rounds a position to the centre of the nearest grid cell. This changes the
-- precision of the value, not where it can be: snapping is not a bound.
function Grid.snap(position: Vector3): Vector3
	local cell = Grid.CELL_SIZE
	return Vector3.new(
		math.floor(position.X / cell + 0.5) * cell,
		position.Y,
		math.floor(position.Z / cell + 0.5) * cell
	)
end

return Grid
