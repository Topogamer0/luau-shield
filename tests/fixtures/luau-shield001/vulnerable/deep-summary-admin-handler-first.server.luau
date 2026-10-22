-- Vulnerable (v0.2.0 review): the admin handler comes first; the public handler reaching the same deep helpers is still exploitable.
-- A deep helper chain (deeper than max-call-depth) ends in a variadic
-- utility. The admin handler is analysed first; the public handler reuses
-- the cached return summary.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local data = {}

local function first(...)
	local value = ...
	return value
end
local function step7(x) return first(x) end
local function step6(x) return step7(x) end
local function step5(x) return step6(x) end
local function step4(x) return step5(x) end
local function step3(x) return step4(x) end
local function step2(x) return step3(x) end
local function step1(x) return step2(x) end

ReplicatedStorage.Remotes.AdminSetCoins.OnServerEvent:Connect(function(player, amount)
	if not Admins.isAdmin(player) then
		return
	end
	data[player].Coins = step1(amount)
end)

ReplicatedStorage.Remotes.ClaimReward.OnServerEvent:Connect(function(player, amount)
	data[player].Coins = step1(amount) -- expect: luau-shield001
end)
