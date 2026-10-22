--!strict
-- Furniture placement, fixed: the template must be a direct child of
-- ReplicatedStorage.Items, the free catalog (a location check on the
-- Instance). Game-pass items live in another folder and are placed through a
-- remote that checks the pass, and furniture already placed in a plot is
-- rejected. The os.clock() cooldown is the rate limit for :Clone().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceItem = ReplicatedStorage.Remotes.PlaceItem :: RemoteEvent
local Items = ReplicatedStorage:WaitForChild("Items")
local Plots = workspace:WaitForChild("Plots")

local PLACE_COOLDOWN = 0.5
local lastPlace: { [Player]: number } = {}

PlaceItem.OnServerEvent:Connect(function(player: Player, template: Model)
	local now = os.clock()
	if now - (lastPlace[player] or 0) < PLACE_COOLDOWN then
		return
	end
	lastPlace[player] = now

	if typeof(template) ~= "Instance" or template.Parent ~= Items or not template:IsA("Model") then
		return
	end
	local plot = Plots:FindFirstChild(player.Name)
	if not plot then
		return
	end

	local copy = template:Clone()
	copy:PivotTo(plot:GetPivot())
	copy.Parent = plot
end)
