local PurchaseRequest = {}
PurchaseRequest.__index = PurchaseRequest

function PurchaseRequest.new(player, payload)
	return setmetatable({
		player = player,
		itemId = payload.itemId,
		quantity = payload.quantity,
	}, PurchaseRequest)
end

function PurchaseRequest:getQuantity()
	return self.quantity
end

return PurchaseRequest
