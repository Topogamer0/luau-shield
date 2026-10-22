--!strict
-- Validation helpers for values received from remotes. Luau type annotations
-- are erased at runtime, so every argument is checked before it is used.
-- NaN fails every comparison: the range checks are written in the "must be
-- true" form and also test `value == value`.

local Validate = {}

export type Range = {
	min: number,
	max: number,
}

-- A number in [min, max], never NaN.
function Validate.isNumberInRange(value: unknown, min: number, max: number): boolean
	return typeof(value) == "number" and value == value and value >= min and value <= max
end

-- A whole number in [min, max] (`math.huge % 1` is NaN, so infinity fails too).
function Validate.isIntegerInRange(value: unknown, min: number, max: number): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= min and value <= max
end

-- A non-empty string of at most `maxLength` bytes.
function Validate.isShortString(value: unknown, maxLength: number): boolean
	return typeof(value) == "string" and #value > 0 and #value <= maxLength
end

return Validate
