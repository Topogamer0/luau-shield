-- Vulnerable (v0.2.0 review): a deep method returns what the client put in `self`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ShopService = require(ServerScriptService.Services.ShopService)

ReplicatedStorage.Remotes.Purchase.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	ShopService.purchase(player, payload)
end)
