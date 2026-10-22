--!strict
-- Inventory UI: clicking a slot fires EquipTool with the Tool object. The
-- server checks it with t.instanceIsA("Tool") and parents it to the
-- player's character. t.instanceIsA only proves the TYPE (an Instance that
-- is a Tool), not that the player owns it. The new Parent value,
-- player.Character, is server-owned, so this is not a luau-shield002: the problem is
-- the Instance being moved.
--
-- Exploit: fire EquipTool with ReplicatedStorage.ShopItems.GoldenSword (the
-- template the shop clones from) to get a paid weapon for free, or with the
-- tool another player is holding (it lives in their character in Workspace)
-- to take it out of their hands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local EquipTool = ReplicatedStorage.Remotes.EquipTool :: RemoteEvent

local isTool = t.instanceIsA("Tool")

EquipTool.OnServerEvent:Connect(function(player: Player, tool: Tool)
	if not isTool(tool) then
		return
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid:UnequipTools()
	tool.Parent = player.Character -- expect: luau-shield003
end)
