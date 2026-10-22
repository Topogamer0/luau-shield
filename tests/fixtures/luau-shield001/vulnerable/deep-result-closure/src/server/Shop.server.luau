-- Vulnerable (v0.2.0 review): a closure returned past the call depth (`result.unwrap()`) still returns the client's quantity.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PurchaseService = require(ServerScriptService.Services.PurchaseService)

ReplicatedStorage.Remotes.Sell.OnServerEvent:Connect(function(player, itemId, quantity)
	local result = PurchaseService.prepare(player, itemId, quantity)
	if not result.ok then
		return
	end
	local count = result.unwrap()
	player.leaderstats.Coins.Value += 10 * count -- expect: luau-shield001
end)
