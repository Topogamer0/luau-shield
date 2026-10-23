local ServerScriptService = game:GetService("ServerScriptService")
local Economy = require(ServerScriptService.Economy)
local Shop = {}
function Shop.quote(amount) return Economy.prepare(amount) end
return Shop
