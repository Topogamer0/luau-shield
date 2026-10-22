-- Safe: depositing coins into the bank. The amount comes from the client but
-- goes through a validation function defined in this file; luau-shield
-- analyses it and learns that, when it returns true, the amount is a number,
-- not NaN, and within [1, MAX_DEPOSIT]. The wallet check runs before any
-- stat changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Deposit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Deposit") :: RemoteEvent

local MAX_DEPOSIT = 1_000_000

local function isValidAmount(value: unknown): boolean
	return typeof(value) == "number" and value == value and value >= 1 and value <= MAX_DEPOSIT and value % 1 == 0
end

local function onDeposit(player: Player, amount: number)
	if not isValidAmount(amount) then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local wallet = leaderstats:FindFirstChild("Coins")
	local bank = leaderstats:FindFirstChild("Bank")
	if not wallet or not bank or wallet.Value < amount then
		return
	end

	wallet.Value -= amount
	bank.Value += amount
end

Deposit.OnServerEvent:Connect(onDeposit)
