-- Safe (luau-shield v0.2.0 report, case 3): `Look.sanitize` builds a new
-- table field by field; every field goes through `clampIndex`, which checks
-- the type, NaN, integer and range and falls back to a default.
local Look = {}

local function clampIndex(v, max, default)
	if type(v) ~= "number" or v ~= v or v % 1 ~= 0 or v < 1 or v > max then return default end
	return v
end

function Look.sanitize(raw)
	local input = if type(raw) == "table" then raw else {}
	return { hair = clampIndex(input.hair, 10, 1), skin = clampIndex(input.skin, 5, 1) }
end

return Look
