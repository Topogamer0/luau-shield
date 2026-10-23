-- Vulnerable: `Look.sanitize` checks `hair` but copies `skin` as the client
-- sent it, so any value (a huge number, NaN, a string) is saved.
local Look = {}

local function clampIndex(v, max, default)
	if type(v) ~= "number" or v ~= v or v % 1 ~= 0 or v < 1 or v > max then return default end
	return v
end

function Look.sanitize(raw)
	local input = if type(raw) == "table" then raw else {}
	return { hair = clampIndex(input.hair, 10, 1), skin = input.skin }
end

return Look
