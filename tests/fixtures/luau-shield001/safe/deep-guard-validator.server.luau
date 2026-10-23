-- Safe (v0.2.0 review): a validator used as a guard beyond the call depth still counts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Validate = {}
function Validate.amount(v)
	return typeof(v) == "number" and v == v and v >= 1 and v <= 10 and v % 1 == 0
end

local Shop = {}
function Shop.purchase(player, amount)
	if not Validate.amount(amount) then
		return
	end
	player.leaderstats.Coins.Value -= amount * 10
	player.leaderstats.Potions.Value += amount
end

local Service = {}
function Service.handle(player, amount) Shop.purchase(player, amount) end
local function route(player, amount) Service.handle(player, amount) end
local function dispatch(player, amount) route(player, amount) end
local function onRequest(player, amount) dispatch(player, amount) end

Remotes.BuyPotions.OnServerEvent:Connect(function(player, amount)
	onRequest(player, amount)
end)
