local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Result)

local Rules = {}

function Rules.quantity(quantity)
	-- BUG: no type, NaN or range check
	return Result.ok(quantity)
end

function Rules.check(kind, value)
	if kind == "quantity" then
		return Rules.quantity(value)
	end
	return Result.err("unknown rule")
end

return Rules
