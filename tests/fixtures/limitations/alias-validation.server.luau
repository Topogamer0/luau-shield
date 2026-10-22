-- Limitation: a check on a copy of a variable does not protect the original.
-- `n` and `amount` hold the same number, and `n` is fully validated (type,
-- NaN, both bounds), so the write is safe. luau-shield only refines the
-- variable that was checked and reports `amount` (false positive).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Remotes.Donate.OnServerEvent:Connect(function(player: Player, amount: unknown)
	local n = amount
	if typeof(n) ~= "number" or n ~= n or n < 1 or n > 100 then
		return
	end
	player.leaderstats.Coins.Value -= amount
end)
