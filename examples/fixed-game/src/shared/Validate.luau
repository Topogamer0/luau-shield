--!strict
-- Validation helpers for values received from remotes. Luau type
-- annotations are erased at runtime: an exploiter can send any value (a
-- string, a table, NaN, math.huge, another player's Instance...) for any
-- parameter, so every argument is checked before the server uses it.
--
-- NaN fails every comparison, so the range checks are written in the
-- "must be true" form and also test `value == value`.

local Config = require(script.Parent.Config)

local Validate = {}

-- A finite number in [min, max].
function Validate.isNumberInRange(value: unknown, min: number, max: number): boolean
	return typeof(value) == "number" and value == value and value >= min and value <= max
end

-- A whole number in [min, max] (`value % 1` is NaN for math.huge).
function Validate.isIntegerInRange(value: unknown, min: number, max: number): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
end

-- A non-empty string of at most `maxLength` bytes.
function Validate.isShortString(value: unknown, maxLength: number): boolean
	return typeof(value) == "string" and #value > 0 and #value <= maxLength
end

-- The id of an item of the shop catalog.
function Validate.isItemId(value: unknown): boolean
	return typeof(value) == "string" and Config.Items[value] ~= nil
end

-- A Vector3 without NaN components, at most `maxDistance` studs from `center`.
function Validate.isNearPosition(value: unknown, center: Vector3, maxDistance: number): boolean
	return typeof(value) == "Vector3" and value == value and (value - center).Magnitude <= maxDistance
end

return Validate
