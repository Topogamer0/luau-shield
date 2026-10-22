-- Safe: the same sanitizer, reached through format migrations, more calls
-- deep than luau-shield follows one by one. What `clampIndex` returns is
-- summarised once and reused, so its checks still count.
local Look = {}

local function clampIndex(v, max, default)
	if type(v) ~= "number" or v ~= v or v % 1 ~= 0 or v < 1 or v > max then return default end
	return v
end

function Look.sanitize(raw)
	local input = if type(raw) == "table" then raw else {}
	return { hair = clampIndex(input.hair, 10, 1), skin = clampIndex(input.skin, 5, 1) }
end

-- Older clients send older formats: each migration hands over to the next.
function Look.fromV3(raw)
	return Look.sanitize(raw)
end

function Look.fromV2(raw)
	if type(raw) == "table" and raw.hairStyle ~= nil then
		return Look.fromV3({ hair = raw.hairStyle, skin = raw.skin })
	end
	return Look.fromV3(raw)
end

function Look.fromV1(raw)
	return Look.fromV2(raw)
end

return Look
