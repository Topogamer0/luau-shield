-- Shop: buys items with coins and hands out the tools a player owns.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local DataManager = require(ServerScriptService.Server.Modules.DataManager)
local Economy = require(ServerScriptService.Server.Modules.Economy)
local Remotes = require(ServerScriptService.Server.Modules.Remotes)

local toolTemplates = ServerStorage:WaitForChild("Tools")

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

-- The shop GUI already shows every price, so it sends the price of the item
-- the player clicked; this saves a catalog lookup on the server.
Remotes.BuyItem.OnServerEvent:Connect(function(player: Player, itemId: string, price: number)
	local profile = DataManager.get(player)
	if not profile or profile.Inventory[itemId] then
		return -- profile not loaded yet, or the item is already owned
	end
	if not Economy.trySpend(player, price) then
		return -- not enough coins
	end
	profile.Inventory[itemId] = true
	giveTool(player, itemId)
end)
