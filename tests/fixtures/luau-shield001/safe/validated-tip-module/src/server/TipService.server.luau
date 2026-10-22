-- Safe: tipping another player (twin of the vulnerable module-economy-helper
-- and weak-validator-module entries). The amount goes through
-- Validate.isIntegerInRange from the shared module before it is passed to
-- the Economy helpers, which write leaderstats. luau-shield follows both
-- requires: the validator proves the type, NaN rejection and both bounds, so
-- the writes inside Economy receive a checked value. The recipient is found
-- with a server lookup (Players:GetPlayerByUserId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validate = require(ReplicatedStorage.Shared.Validate)
local Economy = require(script.Parent.Economy)

local TipPlayer = ReplicatedStorage.Remotes.TipPlayer :: RemoteEvent

local MAX_TIP = 500

TipPlayer.OnServerEvent:Connect(function(player: Player, targetUserId: number, amount: number)
	if typeof(targetUserId) ~= "number" or not Validate.isIntegerInRange(amount, 1, MAX_TIP) then
		return
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	if Economy.trySpend(player, amount) then
		Economy.addCoins(target, amount)
	end
end)
