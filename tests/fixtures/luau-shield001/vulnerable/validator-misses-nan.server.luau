--!strict
-- Vulnerable: slot machine. The bet goes through isValidBet, a validation
-- function in this file that luau-shield analyses. It checks the type and
-- both limits, but returns false only when a comparison is true: every
-- comparison with NaN is false, so isValidBet(0 / 0) returns true.
--
-- Exploit: invoke SpinSlots with 0/0. The `Cash < bet` affordability check is
-- false for NaN too, and Cash becomes NaN: every later `price > Cash` check
-- in the shop fails, so everything is free.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Modules.ProfileStore)

local SpinSlots = ReplicatedStorage.Remotes.SpinSlots :: RemoteFunction

local MIN_BET = 10
local MAX_BET = 5_000
local MULTIPLIERS = { 0, 0, 0, 1, 2, 5 }

local function isValidBet(bet: unknown): boolean
	if typeof(bet) ~= "number" then
		return false
	end
	if bet < MIN_BET or bet > MAX_BET then
		return false
	end
	return true
end

SpinSlots.OnServerInvoke = function(player: Player, bet: number): number?
	local profile = ProfileStore.Profiles[player]
	if not profile or not isValidBet(bet) or profile.Data.Cash < bet then
		return nil
	end
	local multiplier = MULTIPLIERS[math.random(#MULTIPLIERS)]
	profile.Data.Cash -= bet -- expect: luau-shield001
	profile.Data.Cash += bet * multiplier -- expect: luau-shield001
	return multiplier
end
