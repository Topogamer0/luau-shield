--!strict
-- Vulnerable: withdrawing from the bank. The requested amount is clamped to
-- [1, balance], which handles negative and huge numbers, but math.clamp
-- returns NaN when it is given NaN.
--
-- Exploit: invoke Withdraw with 0/0. BankBalance and Cash both become NaN, so
-- every later "can afford" check (`price > account.Cash`) is false and the
-- shop becomes free.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Withdraw = ReplicatedStorage.Remotes.Withdraw :: RemoteFunction

type Account = { Cash: number, BankBalance: number }

local accounts: { [Player]: Account } = {}

Players.PlayerAdded:Connect(function(player)
	accounts[player] = { Cash = 0, BankBalance = 500 }
end)

Withdraw.OnServerInvoke = function(player: Player, requested: unknown): boolean
	local account = accounts[player]
	if not account or typeof(requested) ~= "number" or account.BankBalance < 1 then
		return false
	end

	local amount = math.clamp(requested, 1, account.BankBalance)
	account.BankBalance -= amount -- expect: luau-shield001
	account.Cash += amount -- expect: luau-shield001
	return true
end
