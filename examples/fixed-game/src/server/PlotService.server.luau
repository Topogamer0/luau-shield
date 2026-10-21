-- Plots: every player gets a plot where they can place the furniture they
-- bought in the shop, and remove it again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataManager = require(script.Parent.Modules.DataManager)
local Remotes = require(script.Parent.Modules.Remotes)

local furniture = ServerStorage:WaitForChild("Furniture")
local plots = workspace:WaitForChild("Plots")
local lastPlace: { [Player]: number } = {}

-- The only rotations the client may ask for (degrees around Y).
local ROTATIONS: { [number]: CFrame } = {
	[0] = CFrame.Angles(0, 0, 0),
	[90] = CFrame.Angles(0, math.rad(90), 0),
	[180] = CFrame.Angles(0, math.rad(180), 0),
	[270] = CFrame.Angles(0, math.rad(270), 0),
}

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
	lastPlace[player] = nil
	local plot = getPlot(player)
	if plot then
		plot.Objects:ClearAllChildren()
		plot:SetAttribute("OwnerId", nil)
	end
end)

-- The client sends the item, the position under the mouse and a rotation.
Remotes.PlaceObject.OnServerEvent:Connect(function(player: Player, itemId: unknown, position: unknown, rotation: unknown)
	local now = os.clock()
	if now - (lastPlace[player] or 0) < Config.PlaceCooldown then
		return
	end
	lastPlace[player] = now

	local profile = DataManager.get(player)
	local plot = getPlot(player)
	if not profile or not plot or not Validate.isItemId(itemId) or not profile.Inventory[itemId] then
		return -- only owned furniture can be placed
	end
	local turn = ROTATIONS[rotation]
	if not turn or profile.PlotObjects >= Config.MaxPlotObjects then
		return
	end
	if not Validate.isNearPosition(position, plot:GetPivot().Position, Config.PlotRadius) then
		return -- outside the player's own plot (or not a valid Vector3)
	end
	local template = furniture:FindFirstChild(itemId)
	if not template then
		return
	end
	local object = template:Clone()
	object:PivotTo(CFrame.new(position) * turn)
	object:SetAttribute("OwnerId", player.UserId)
	object.Parent = plot.Objects
	profile.PlotObjects += 1
end)

-- The client sends the placed object under the mouse when the player presses X.
Remotes.DeleteObject.OnServerEvent:Connect(function(player: Player, object: unknown)
	local profile = DataManager.get(player)
	local plot = getPlot(player)
	if not profile or not plot or typeof(object) ~= "Instance" then
		return
	end
	-- Only objects placed by this player, directly in their own plot.
	if object.Parent ~= plot.Objects or object:GetAttribute("OwnerId") ~= player.UserId then
		return
	end
	object:Destroy()
	profile.PlotObjects -= 1
end)
