--!strict
-- Safe: withdrawing from the bank (twin of the vulnerable clamp-nan entry).
-- The amount is checked with the t library: t.numberConstrained proves the
-- type and the range, the explicit `amount ~= amount` test rejects NaN, and
-- the balance check gives the real upper bound. The checked amount is then
-- written as it is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local Withdraw = ReplicatedStorage.Remotes.Withdraw :: RemoteFunction

local MAX_WITHDRAW = 100_000

type Account = { Cash: number, BankBalance: number }

local accounts: { [Player]: Account } = {}

local isWithdrawAmount = t.numberConstrained(1, MAX_WITHDRAW)

Players.PlayerAdded:Connect(function(player)
	accounts[player] = { Cash = 0, BankBalance = 500 }
end)

Withdraw.OnServerInvoke = function(player: Player, amount: number): boolean
	local account = accounts[player]
	if not account or not isWithdrawAmount(amount) or amount ~= amount then
		return false
	end
	if amount > account.BankBalance then
		return false
	end

	account.BankBalance -= amount
	account.Cash += amount
	return true
end
