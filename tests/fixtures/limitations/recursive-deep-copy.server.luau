-- Limitation: a recursive deepCopy of a nested patch. `Coins` is type-checked,
-- NaN-checked and clamped, so the write is safe, but the recursive call is
-- cut off (recursion is not followed), its result loses the checks and the
-- write is reported (false positive).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.ClaimCoins
local Profiles = {}

local function deepCopy(t)
	local out = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			out[k] = deepCopy(v)
		else
			out[k] = v
		end
	end
	return out
end

local function applyPatch(player, patch)
	local changed = deepCopy(patch)
	local data = Profiles[player].Data
	if changed.Stats and changed.Stats.Coins ~= nil then
		data.Coins = changed.Stats.Coins
	end
end

remote.OnServerEvent:Connect(function(player, amount)
	if typeof(amount) ~= "number" or amount ~= amount then return end
	applyPatch(player, { Stats = { Coins = math.clamp(amount, 0, 100) } })
end)
