-- Safe (v0.2.0 review): the same deep range validator with server bounds.
-- Transfer handler: the validator compares the amount with the balance the CLIENT
-- claims to have. The guard sits six calls deep (past max-call-depth).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function inRange(value, min, max)
	return typeof(value) == "number" and value == value and value >= min and value <= max
end

local function applyTransfer(player, amount, claimedBalance)
	if not inRange(amount, 1, 1000) then
		return
	end
	player.leaderstats.Coins.Value += amount
end
local function l4(player, amount, balance) return applyTransfer(player, amount, balance) end
local function l3(player, amount, balance) return l4(player, amount, balance) end
local function l2(player, amount, balance) return l3(player, amount, balance) end
local function l1(player, amount, balance) return l2(player, amount, balance) end

ReplicatedStorage.Remotes.Transfer.OnServerEvent:Connect(function(player, amount, balance)
	l1(player, amount, balance)
end)
