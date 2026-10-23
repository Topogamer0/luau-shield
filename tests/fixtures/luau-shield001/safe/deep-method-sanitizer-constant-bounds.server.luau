-- Safe (v0.2.0 review): a deep method sanitizer with constant bounds on a table that also stores client carts.
-- Service method with constant bounds, reached past max-call-depth; the service
-- table also stores each player's last (client) cart.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = {}
Shop.carts = {}

function Shop:clampQuantity(quantity)
	if typeof(quantity) ~= "number" or quantity ~= quantity then
		return 1
	end
	return math.clamp(math.floor(quantity), 1, 99)
end

local function l5(q) return Shop:clampQuantity(q) end
local function l4(q) return l5(q) end
local function l3(q) return l4(q) end
local function l2(q) return l3(q) end
local function l1(q) return l2(q) end

ReplicatedStorage.Remotes.Buy.OnServerEvent:Connect(function(player, cart, quantity)
	Shop.carts[player] = cart
	local count = l1(quantity)
	player.leaderstats.Potions.Value += count
end)
