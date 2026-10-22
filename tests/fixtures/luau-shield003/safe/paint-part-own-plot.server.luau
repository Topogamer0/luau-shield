--!strict
-- Building game paint tool, fixed: the server finds the plot whose "Owner"
-- attribute is this player's UserId, and the part must be a descendant of
-- that plot. Other players' builds, the lobby and characters are rejected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaintPart = ReplicatedStorage.Remotes.PaintPart :: RemoteEvent
local Plots = workspace:WaitForChild("Plots")

local function getPlot(player: Player): Instance?
	for _, plot in Plots:GetChildren() do
		if plot:GetAttribute("Owner") == player.UserId then
			return plot
		end
	end
	return nil
end

local function onPaint(player: Player, part: BasePart, color: Color3)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	if typeof(color) ~= "Color3" then
		return
	end

	local plot = getPlot(player)
	if not plot or not part:IsDescendantOf(plot) then
		return
	end

	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part:SetAttribute("PaintedBy", player.UserId)
end

PaintPart.OnServerEvent:Connect(onPaint)
