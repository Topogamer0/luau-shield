local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trace = require(ReplicatedStorage.Shared.Trace)
local Economy = {}
local function normalize(amount) return Trace.pass("normalize", amount) end
local function applyBonus(amount) return normalize(amount) end
local function applyTax(amount) return applyBonus(amount) end
local function convert(amount) return applyTax(amount) end
function Economy.prepare(amount) return convert(amount) end
return Economy
