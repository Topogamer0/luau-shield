local ServerScriptService = game:GetService("ServerScriptService")
local Rules = require(ServerScriptService.Services.Rules)

local ValidationService = {}

function ValidationService.validate(kind, value)
	return Rules.check(kind, value)
end

return ValidationService
