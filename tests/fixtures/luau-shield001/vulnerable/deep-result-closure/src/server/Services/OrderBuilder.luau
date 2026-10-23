local ServerScriptService = game:GetService("ServerScriptService")
local ValidationService = require(ServerScriptService.Services.ValidationService)

local OrderBuilder = {}

function OrderBuilder.build(itemId, quantity)
	return ValidationService.validate("quantity", quantity)
end

return OrderBuilder
