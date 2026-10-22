--!strict
-- Shared validation helpers (ReplicatedStorage.Shared.Validate).
--
-- isFurniture is resolved and analysed by luau-shield, so its NAME does not
-- make it a trusted validator: what counts is what it checks. When it returns
-- true, `value` is known to be an Instance (a Model) with a "Furniture"
-- attribute. That is a type check, not an ownership check.

local Validate = {}

function Validate.isFurniture(value: unknown): boolean
	return typeof(value) == "Instance" and value:IsA("Model") and value:GetAttribute("Furniture") == true
end

return Validate
