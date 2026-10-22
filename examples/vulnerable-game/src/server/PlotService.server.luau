-- Plots: every player gets a plot where they can place the furniture they
-- bought in the shop, and remove it again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataManager = require(script.Parent.Modules.DataManager)
local Remotes = require(script.Parent.Modules.Remotes)

local furniture = ServerStorage:WaitForChild("Furniture")
local plots = workspace:WaitForChild("Plots")

local function getPlot(player: Player): Model?
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId then
			return plot :: Model
		end
	end
	return nil
end

Players.PlayerAdded:Connect(function(player)
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == nil then
			plot:SetAttribute("OwnerId", player.UserId)
			return
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local plot = getPlot(player)
	if plot then
		plot.Objects:ClearAllChildren()
		plot:SetAttribute("OwnerId", nil)
	end
end)

-- The client shows a preview of the furniture under the mouse and sends the
-- CFrame of the preview when the player confirms.
Remotes.PlaceObject.OnServerEvent:Connect(function(player: Player, itemId: string, cframe: CFrame)
	local profile = DataManager.get(player)
	local plot = getPlot(player)
	if not profile or not plot or not profile.Inventory[itemId] then
		return -- only owned furniture can be placed
	end
	if profile.PlotObjects >= Config.MaxPlotObjects then
		return
	end
	local template = furniture:FindFirstChild(itemId)
	if not template then
		return
	end
	local object = template:Clone()
	object:PivotTo(cframe)
	object:SetAttribute("OwnerId", player.UserId)
	object.Parent = plot.Objects
	profile.PlotObjects += 1
end)

-- The client sends the model under the mouse when the player presses X.
Remotes.DeleteObject.OnServerEvent:Connect(function(player: Player, object: Model)
	local profile = DataManager.get(player)
	if not profile or typeof(object) ~= "Instance" or not object:IsA("Model") then
		return
	end
	object:Destroy()
	profile.PlotObjects -= 1
end)
