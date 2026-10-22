-- Limitation: an anchored pattern is accepted as a check for keys, but it
-- only constrains the FORMAT. `^%w+$` still lets the client name any item, so
-- this write grants free items. luau-shield accepts the pattern (false
-- negative); allow-list item ids against the catalog instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData: { [Player]: { Inventory: { [string]: boolean } } } = {}

ReplicatedStorage.Remotes.ClaimItem.OnServerEvent:Connect(function(player: Player, itemName: string)
	if typeof(itemName) ~= "string" or not itemName:match("^%w+$") then
		return
	end
	local data = PlayerData[player]
	if not data then
		return
	end
	data.Inventory[itemName] = true -- expect: luau-shield001
end)
