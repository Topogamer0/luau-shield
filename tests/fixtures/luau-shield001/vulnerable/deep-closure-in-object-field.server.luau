-- Vulnerable (v0.2.0 review): a closure stored in an object built past the call depth reads the client's amount.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage.Remotes.Act
local function F(x)
	local self = {}
	function self.get() return x end
	return self
end
local function l5(player, amount) return F(amount).get() end
local function l4(player, amount) return l5(player, amount) end
local function l3(player, amount) return l4(player, amount) end
local function l2(player, amount) return l3(player, amount) end
local function l1(player, amount) return l2(player, amount) end
remote.OnServerEvent:Connect(function(player, amount)
	local result = l1(player, amount)
	player.leaderstats.Coins.Value += result -- expect: luau-shield001
end)
