--!strict
-- Pawn shop: the client invokes SellTool with the Tool to sell. The server
-- checks that it is a Tool, pays its sell price (an IntValue child the server
-- put in every tool) and destroys it. Once the tool is known to be an
-- Instance, tool.Price.Value is server data, so this is not a luau-shield001; the
-- problem is that the CLIENT picked the tool. Paying out its price is the
-- first use, so luau-shield003 is reported on the leaderstats line.
--
-- Exploit: invoke SellTool with the sword another player is holding (it is in
-- their character, in Workspace). The exploiter gets the cash and the victim
-- loses the tool. Repeat for every player on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SellTool = ReplicatedStorage.Remotes.SellTool :: RemoteFunction

SellTool.OnServerInvoke = function(player: Player, tool: Tool): (boolean, number?)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return false, nil
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = if leaderstats then leaderstats:FindFirstChild("Cash") :: IntValue? else nil
	if not cash then
		return false, nil
	end

	cash.Value += tool.Price.Value -- expect: luau-shield003
	tool:Destroy()
	return true, cash.Value
end
