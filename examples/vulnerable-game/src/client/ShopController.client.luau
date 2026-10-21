-- Shop window and building controls.
--   Click an item in the shop to buy it; furniture becomes the selected item.
--   E places the selected item at the mouse, R rotates it, X removes the
--   object under the mouse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local shop = player:WaitForChild("PlayerGui"):WaitForChild("Shop")
local itemList = shop:WaitForChild("ItemList")
local itemTemplate = itemList:WaitForChild("ItemTemplate") :: TextButton

local selectedItem: string? = nil
local rotation = 0

for itemId, item in Config.Items do
	local button = itemTemplate:Clone()
	button.Name = itemId
	button.Text = `{item.DisplayName} ({item.Price} coins)`
	button.Visible = true
	button.Parent = itemList
	button.Activated:Connect(function()
		Remotes.BuyItem:FireServer(itemId, item.Price)
		if item.Placeable then
			selectedItem = itemId
		end
	end)
end

local function modelUnderMouse(): Model?
	local part = mouse.Target
	return if part then part:FindFirstAncestorOfClass("Model") else nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E and selectedItem then
		local cframe = CFrame.new(mouse.Hit.Position) * CFrame.Angles(0, math.rad(rotation), 0)
		Remotes.PlaceObject:FireServer(selectedItem, cframe)
	elseif input.KeyCode == Enum.KeyCode.R then
		rotation = (rotation + 90) % 360
	elseif input.KeyCode == Enum.KeyCode.X then
		local model = modelUnderMouse()
		if model then
			Remotes.DeleteObject:FireServer(model)
		end
	end
end)
