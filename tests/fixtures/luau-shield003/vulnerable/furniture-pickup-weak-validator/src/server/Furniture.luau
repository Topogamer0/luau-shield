--!strict
-- Server furniture helpers (ServerScriptService.Furniture).
--
-- pickUp moves a placed model back into the player's furniture inventory
-- (a folder under the Player that the save script serialises). It trusts the
-- caller to pass a model that belongs to the player. The finding is reported
-- here, on the first statement that uses the model.

local Furniture = {}

function Furniture.getInventory(player: Player): Folder?
	local inventory = player:FindFirstChild("FurnitureInventory")
	return if inventory and inventory:IsA("Folder") then inventory else nil
end

function Furniture.pickUp(player: Player, model: Model)
	local inventory = Furniture.getInventory(player)
	if not inventory then
		return
	end
	model.Parent = inventory -- expect: luau-shield003
	model:SetAttribute("PlacedAt", nil)
end

return Furniture
