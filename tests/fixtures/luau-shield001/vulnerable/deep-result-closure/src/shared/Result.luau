-- Small Result type: values are captured by closures.
local Result = {}

function Result.ok(value)
	return {
		ok = true,
		unwrap = function()
			return value
		end,
	}
end

function Result.err(message)
	return {
		ok = false,
		unwrap = function()
			error(message)
		end,
	}
end

return Result
