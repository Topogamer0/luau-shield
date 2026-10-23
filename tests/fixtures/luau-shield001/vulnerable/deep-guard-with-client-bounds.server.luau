-- Vulnerable (v0.2.0 review): a deep range validator whose bounds are sent by the client.
-- Range validator used as a guard past max-call-depth, with bounds sent by the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function inRange(value, min, max)
	return typeof(value) == "number" and value == value and value >= min and value <= max
end

local function l5(player, amount, limits)
	if not inRange(amount, limits.min, limits.max) then
		return
	end
	player.leaderstats.Coins.Value += amount -- expect: luau-shield001
end
local function l4(...) return l5(...) end
local function l3(...) return l4(...) end
local function l2(...) return l3(...) end
local function l1(...) return l2(...) end

ReplicatedStorage.Remotes.Donate.OnServerEvent:Connect(function(player, amount, limits)
	l1(player, amount, limits)
end)
