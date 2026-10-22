-- Vulnerable (v0.2.0 review): an unresolved method inside a summarised function is not a trusted validator.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local AmountPolicy = {}
AmountPolicy.__index = AmountPolicy

function AmountPolicy.new(max)
	return setmetatable({ max = max }, AmountPolicy)
end

function AmountPolicy:isNumber(v)
	return typeof(v) == "number"
end

-- Only checks the type: NaN, negative and huge amounts get through.
function AmountPolicy:normalize(v)
	if not self:isNumber(v) then
		return 0
	end
	return v
end

local policy = AmountPolicy.new(1000)

local function d5(v) return policy:normalize(v) end
local function d4(v) return d5(v) end
local function d3(v) return d4(v) end
local function d2(v) return d3(v) end
local function d1(v) return d2(v) end

Remotes.DepositShallow.OnServerEvent:Connect(function(player, amount)
	player.leaderstats.Bank.Value += policy:normalize(amount) -- expect: luau-shield001
end)

Remotes.DepositDeep.OnServerEvent:Connect(function(player, amount)
	player.leaderstats.Bank.Value += d1(amount) -- expect: luau-shield001
end)
