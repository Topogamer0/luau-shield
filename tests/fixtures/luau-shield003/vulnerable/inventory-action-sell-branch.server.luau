--!strict
-- Inventory actions: one remote serves every button of the inventory UI
-- (ItemAction:FireServer(action, tool)). The "Equip" branch checks that the
-- tool is in the player's Backpack, but the check was written inside that
-- branch only, and the "Sell" branch uses the tool without it. A check only
-- protects the code that runs after it succeeds, on the same path: the
-- client chooses the action, so it chooses the unchecked path.
--
-- Exploit: fire ItemAction("Sell", tool) with the tools other players are
-- holding (they live in their characters, in Workspace). The victims lose
-- their weapons and the exploiter is paid for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemAction = ReplicatedStorage.Remotes.ItemAction :: RemoteEvent

local SELL_PRICES: { [string]: number } = { Sword = 50, Bow = 80, Staff = 120 }

local function onItemAction(player: Player, action: string, tool: Tool)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack or not character or typeof(tool) ~= "Instance" then
		return
	end

	if action == "Equip" then
		if tool.Parent ~= backpack then
			return
		end
		tool.Parent = character
	elseif action == "Sell" then
		local price = SELL_PRICES[tool.Name]
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = if leaderstats then leaderstats:FindFirstChild("Cash") :: IntValue? else nil
		if not price or not cash then
			return
		end
		tool:Destroy() -- expect: luau-shield003
		cash.Value += price
	end
end

ItemAction.OnServerEvent:Connect(onItemAction)
