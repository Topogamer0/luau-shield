-- Limitation: tables are tracked by value, not by reference.
-- `pending` and `entry` are the same table, but the client value is written
-- through `entry` and read back through `pending`: luau-shield does not see
-- the alias and misses the write to leaderstats (false negative).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Remotes.Deposit.OnServerEvent:Connect(function(player: Player, amount: number)
	local pending = { amount = 0 }
	local entry = pending
	entry.amount = amount
	player.leaderstats.Coins.Value += pending.amount -- expect: luau-shield001
end)
