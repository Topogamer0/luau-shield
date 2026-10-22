--!strict
-- Storage chests, fixed: the chest sent by the client must be inside the
-- player's own plot (an ownership/location check) before the tool is moved
-- into it. Another player's character or chest is rejected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoreTool = ReplicatedStorage.Remotes.StoreTool :: RemoteEvent

local function onStoreTool(player: Player, toolName: string, chest: Instance)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = if backpack then backpack:FindFirstChild(toolName) else nil
	if not tool or not tool:IsA("Tool") then
		return
	end

	local plot = workspace.Plots:FindFirstChild(player.Name)
	if not plot or typeof(chest) ~= "Instance" or not chest:IsA("Model") then
		return
	end
	if not chest:IsDescendantOf(plot) then
		return
	end

	tool.Parent = chest
end

StoreTool.OnServerEvent:Connect(onStoreTool)
