--!strict
-- Inventory actions, fixed: the Backpack check is done once, before the
-- action is dispatched, so every branch (including the ones added later)
-- only ever sees the player's own tools.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemAction = ReplicatedStorage.Remotes.ItemAction :: RemoteEvent

local SELL_PRICES: { [string]: number } = { Sword = 50, Bow = 80, Staff = 120 }

local function onItemAction(player: Player, action: string, tool: Tool)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if not backpack or not character or typeof(tool) ~= "Instance" then
		return
	end
	if tool.Parent ~= backpack then
		return
	end

	if action == "Equip" then
		tool.Parent = character
	elseif action == "Sell" then
		local price = SELL_PRICES[tool.Name]
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = if leaderstats then leaderstats:FindFirstChild("Cash") :: IntValue? else nil
		if not price or not cash then
			return
		end
		tool:Destroy()
		cash.Value += price
	end
end

ItemAction.OnServerEvent:Connect(onItemAction)
