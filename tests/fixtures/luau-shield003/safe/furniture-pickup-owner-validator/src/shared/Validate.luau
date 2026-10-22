--!strict
-- Shared validation helpers (ReplicatedStorage.Shared.Validate).
--
-- isOwnedFurniture is resolved and analysed by luau-shield. When it returns
-- true, `value` is a Model whose "Owner" attribute (set by the server when the
-- furniture is placed) equals the player's UserId: an ownership fact.

local Validate = {}

function Validate.isOwnedFurniture(value: unknown, player: Player): boolean
	return typeof(value) == "Instance"
		and value:IsA("Model")
		and value:GetAttribute("Furniture") == true
		and value:GetAttribute("Owner") == player.UserId
end

return Validate
