-- Safe (v0.2.0 review): a deep `math.clamp(n, 1, max)` with a server `max` checks the value.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Whole number between 1 and `max`; NaN and non-numbers become 1.
local function clampIndex(v, max)
	local n = tonumber(v)
	if n == nil or n ~= n then
		return 1
	end
	return math.clamp(math.floor(n), 1, max)
end

local Avatar = {}
function Avatar.sanitize(raw)
	local input = if type(raw) == "table" then raw else {}
	return { hair = clampIndex(input.hair, 10), skin = clampIndex(input.skin, 5) }
end
function Avatar.fromV3(raw) return Avatar.sanitize(raw) end
function Avatar.fromV2(raw) return Avatar.fromV3(raw) end
function Avatar.fromV1(raw) return Avatar.fromV2(raw) end
local function prepareLook(raw) return Avatar.fromV1(raw) end

local saves = {}

Remotes.SetLookShallow.OnServerEvent:Connect(function(player, raw)
	saves[player].Look = Avatar.sanitize(raw)
end)

Remotes.SetLookDeep.OnServerEvent:Connect(function(player, raw)
	saves[player].Look = prepareLook(raw)
end)
