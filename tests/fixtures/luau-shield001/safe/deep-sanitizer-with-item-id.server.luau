-- Safe (v0.2.0 review): a deep sanitizer clamps to the item's server maximum; the item id is also client data.
-- Deep, complete sanitizer whose second argument (the item id) is also client data.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = {
	Sword = { Price = 100, MaxStack = 1 },
	Potion = { Price = 10, MaxStack = 99 },
}

local function sanitizeQuantity(quantity, itemId)
	local item = Items[itemId]
	if not item or typeof(quantity) ~= "number" or quantity ~= quantity then
		return 1
	end
	return math.clamp(math.floor(quantity), 1, item.MaxStack)
end

local function l5(quantity, itemId) return sanitizeQuantity(quantity, itemId) end
local function l4(quantity, itemId) return l5(quantity, itemId) end
local function l3(quantity, itemId) return l4(quantity, itemId) end
local function l2(quantity, itemId) return l3(quantity, itemId) end
local function l1(quantity, itemId) return l2(quantity, itemId) end

ReplicatedStorage.Remotes.Buy.OnServerEvent:Connect(function(player, itemId, quantity)
	local count = l1(quantity, itemId)
	player.leaderstats.Potions.Value += count
end)
