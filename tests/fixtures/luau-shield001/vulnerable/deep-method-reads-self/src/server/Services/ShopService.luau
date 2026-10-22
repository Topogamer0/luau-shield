local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pricing = require(ServerScriptService.Services.Pricing)
local PurchaseRequest = require(ReplicatedStorage.Shared.PurchaseRequest)

local ShopService = {}

local function quote(request)
	return Pricing.total(request)
end

function ShopService.process(player, request)
	local cost = quote(request)
	-- a negative quantity makes the cost negative: the player gains coins
	player.leaderstats.Coins.Value -= cost -- expect: luau-shield001
end

function ShopService.purchase(player, payload)
	local request = PurchaseRequest.new(player, payload)
	ShopService.process(player, request)
end

return ShopService
