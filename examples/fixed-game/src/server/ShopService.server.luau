-- Shop: buys items with coins and hands out the tools a player owns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataManager = require(ServerScriptService.Server.Modules.DataManager)
local Economy = require(ServerScriptService.Server.Modules.Economy)
local Remotes = require(ServerScriptService.Server.Modules.Remotes)

local toolTemplates = ServerStorage:WaitForChild("Tools")
local lastPurchase: { [Player]: number } = {}

local function giveTool(player: Player, itemId: string)
	local template = toolTemplates:FindFirstChild(itemId)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if template and backpack and not backpack:FindFirstChild(itemId) then
		template:Clone().Parent = backpack
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		local profile = DataManager.get(player)
		if not profile then
			return
		end
		for itemId in profile.Inventory do
			giveTool(player, itemId)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastPurchase[player] = nil
end)

-- The client only says which item it wants; the price always comes from
-- the server's copy of the catalog.
Remotes.BuyItem.OnServerEvent:Connect(function(player: Player, itemId: unknown)
	local now = os.clock()
	if now - (lastPurchase[player] or 0) < Config.PurchaseCooldown then
		return
	end
	lastPurchase[player] = now

	if not Validate.isItemId(itemId) then
		return -- not an item of the catalog
	end
	local profile = DataManager.get(player)
	if not profile or profile.Inventory[itemId] then
		return -- profile not loaded yet, or the item is already owned
	end
	local price = Config.Items[itemId].Price
	if not Economy.trySpend(player, price) then
		return -- not enough coins
	end
	profile.Inventory[itemId] = true
	giveTool(player, itemId)
end)
