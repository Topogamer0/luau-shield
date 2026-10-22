--!strict
-- Small validation helpers shared by the client UI and the server handlers.

local Validate = {}

-- True for numbers greater than zero.
function Validate.isPositiveNumber(value: unknown): boolean
	return typeof(value) == "number" and value > 0
end

-- True for non-empty strings of at most `maxLength` bytes.
function Validate.isShortString(value: unknown, maxLength: number): boolean
	return typeof(value) == "string" and #value > 0 and #value <= maxLength
end

-- True when `value` is one of `options`.
function Validate.isOneOf<T>(value: unknown, options: { T }): boolean
	return table.find(options, value :: any) ~= nil
end

return Validate
