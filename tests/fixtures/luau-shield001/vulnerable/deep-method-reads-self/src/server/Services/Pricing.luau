local Pricing = {}

local PRICES = { Potion = 25, Sword = 300, Shield = 250 }

local function subtotal(request)
	local unitPrice = PRICES[request.itemId] or 0
	return unitPrice * request:getQuantity()
end

function Pricing.total(request)
	return subtotal(request)
end

return Pricing
