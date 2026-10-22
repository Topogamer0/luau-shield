--!strict
-- Validation helpers for values received from remotes, shared by the client
-- (to grey out the search button) and the server (to enforce the rules).
-- Luau type annotations are erased at runtime, so every check is explicit.

local Validate = {}

-- A Roblox-style username: 3 to 20 letters, digits or underscores. The
-- pattern is anchored at both ends, so nothing else can follow the name.
function Validate.isUsername(value: unknown): boolean
	if typeof(value) ~= "string" or #value < 3 or #value > 20 then
		return false
	end
	if not string.match(value, "^[%w_]+$") then
		return false
	end
	return true
end

-- A positive whole number, never NaN.
function Validate.isUserId(value: unknown): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0 and value >= 1
end

return Validate
