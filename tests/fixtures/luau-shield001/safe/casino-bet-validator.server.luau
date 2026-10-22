--!strict
-- Safe: slot machine (twin of the vulnerable validator-misses-nan entry). The
-- validation function in this file now also rejects NaN (`bet ~= bet`), so
-- when isValidBet returns true luau-shield knows the bet is a number in
-- [MIN_BET, MAX_BET] and not NaN. The payout reuses the checked bet.

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
	if bet ~= bet or bet < MIN_BET or bet > MAX_BET then
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
	profile.Data.Cash -= bet
	profile.Data.Cash += bet * multiplier
	return multiplier
end
