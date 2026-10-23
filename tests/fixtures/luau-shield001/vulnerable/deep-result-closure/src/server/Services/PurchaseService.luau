local ServerScriptService = game:GetService("ServerScriptService")
local OrderBuilder = require(ServerScriptService.Services.OrderBuilder)

local PurchaseService = {}

function PurchaseService.prepare(player, itemId, quantity)
	return OrderBuilder.build(itemId, quantity)
end

return PurchaseService
