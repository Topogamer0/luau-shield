--!strict
-- Pawn shop, fixed: only tools whose Parent is the player's own Backpack
-- can be sold. Another player's tool, or a shop template in
-- ReplicatedStorage, fails the check before its price is read.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SellTool = ReplicatedStorage.Remotes.SellTool :: RemoteFunction

SellTool.OnServerInvoke = function(player: Player, tool: Tool): (boolean, number?)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or typeof(tool) ~= "Instance" or tool.Parent ~= backpack then
		return false, nil
	end
	if not tool:IsA("Tool") then
		return false, nil
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = if leaderstats then leaderstats:FindFirstChild("Cash") :: IntValue? else nil
	if not cash then
		return false, nil
	end

	cash.Value += tool.Price.Value
	tool:Destroy()
	return true, cash.Value
end
