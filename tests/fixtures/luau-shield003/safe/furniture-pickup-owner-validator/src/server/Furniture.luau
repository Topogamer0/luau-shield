--!strict
-- Server furniture helpers (ServerScriptService.Furniture).
--
-- pickUp moves a placed model back into the player's furniture inventory.
-- Callers must pass a model that passed Validate.isOwnedFurniture.

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
	model.Parent = inventory
	model:SetAttribute("PlacedAt", nil)
end

return Furniture
