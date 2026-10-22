-- Limitation: a module chosen at runtime cannot be resolved statically.
-- The shop module is picked from a folder by a name computed at runtime, then
-- called with the client's price. The write inside Shops/Default.luau should
-- be reported, but `require(Shops[mode])` cannot be resolved, so the module is
-- never analysed with the client value (false negative). With a static path
-- (`require(script.Parent.Shops.Default)`) the flow is followed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function currentMode(): string
	return if workspace:GetAttribute("Event") then "Event" else "Default"
end

ReplicatedStorage.Remotes.Purchase.OnServerEvent:Connect(function(player: Player, price: number)
	local shop = require(script.Parent.Shops[currentMode()])
	shop.charge(player, price)
end)
