-- Limitation: assertions inside a function run with pcall are not guards.
-- The validation asserts every property and the handler returns when pcall
-- reports a failure, so the amount is validated; luau-shield does not connect
-- the asserts in the pcall'd function with the `ok` flag (false positive).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Remotes.Bet.OnServerEvent:Connect(function(player: Player, amount: unknown)
	local ok = pcall(function()
		assert(typeof(amount) == "number")
		assert(amount == amount and amount >= 1 and amount <= 50)
	end)
	if not ok then
		return
	end
	player.leaderstats.Coins.Value -= amount
end)
