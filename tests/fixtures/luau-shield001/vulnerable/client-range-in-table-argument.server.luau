-- Vulnerable (v0.2.0 review): a range whose maximum comes from the client bounds nothing, even inside a table argument.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function clampToRange(value, range)
	if typeof(value) ~= "number" or value ~= value then
		return 1
	end
	if value < range.min or value > range.max then
		return 1
	end
	return value
end

local function d5(v, r) return clampToRange(v, r) end
local function d4(v, r) return d5(v, r) end
local function d3(v, r) return d4(v, r) end
local function d2(v, r) return d3(v, r) end
local function d1(v, r) return d2(v, r) end

-- shallow
Remotes.Cashout.OnServerEvent:Connect(function(player, amount, maxPayout)
	local payout = clampToRange(amount, { min = 1, max = maxPayout })
	player.leaderstats.Coins.Value += payout -- expect: luau-shield001
end)

-- deep
Remotes.CashoutDeep.OnServerEvent:Connect(function(player, amount, maxPayout)
	local payout = d1(amount, { min = 1, max = maxPayout })
	player.leaderstats.Coins.Value += payout -- expect: luau-shield001
end)

-- deep, bound passed directly
local function clampTo(value, min, max)
	if typeof(value) ~= "number" or value ~= value then
		return 1
	end
	if value < min or value > max then
		return 1
	end
	return value
end
local function e5(v, a, b) return clampTo(v, a, b) end
local function e4(v, a, b) return e5(v, a, b) end
local function e3(v, a, b) return e4(v, a, b) end
local function e2(v, a, b) return e3(v, a, b) end
local function e1(v, a, b) return e2(v, a, b) end
Remotes.CashoutDeep2.OnServerEvent:Connect(function(player, amount, maxPayout)
	local payout = e1(amount, 1, maxPayout)
	player.leaderstats.Coins.Value += payout -- expect: luau-shield001
end)
