-- Vulnerable (v0.2.0 review): a deep range validator whose maximum is the balance sent by the client.
-- Transfer handler: the validator compares the amount with the balance the CLIENT
-- claims to have. The guard sits six calls deep (past max-call-depth).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function inRange(value, min, max)
	return typeof(value) == "number" and value == value and value >= min and value <= max
end

local function applyTransfer(player, amount, claimedBalance)
	if not inRange(amount, 1, claimedBalance) then
		return
	end
	player.leaderstats.Coins.Value += amount -- expect: luau-shield001
end
local function l4(player, amount, balance) return applyTransfer(player, amount, balance) end
local function l3(player, amount, balance) return l4(player, amount, balance) end
local function l2(player, amount, balance) return l3(player, amount, balance) end
local function l1(player, amount, balance) return l2(player, amount, balance) end

ReplicatedStorage.Remotes.Transfer.OnServerEvent:Connect(function(player, amount, balance)
	l1(player, amount, balance)
end)
