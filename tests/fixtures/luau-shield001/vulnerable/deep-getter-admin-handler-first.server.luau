-- Vulnerable (v0.2.0 review): a deep getter reached first by an admin handler, then by a public one.
-- The summary of a deep getter is computed in an admin-only handler and reused in a player handler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local Admins = require(script.Parent.Admins)

local lastBonus = 0
local Bonus = {}
function Bonus.set(amount)
	lastBonus = amount
end
function Bonus.get()
	return lastBonus
end

local function l5() return Bonus.get() end
local function l4() return l5() end
local function l3() return l4() end
local function l2() return l3() end
local function l1() return l2() end

-- Admin tool: set the event bonus and grant it to yourself.
Remotes.AdminSetBonus.OnServerEvent:Connect(function(player, amount)
	if not Admins.isAdmin(player) then
		return
	end
	Bonus.set(amount)
	player.leaderstats.Coins.Value += l1()
end)

-- Any player: claim a bonus they choose.
Remotes.ClaimBonus.OnServerEvent:Connect(function(player, amount)
	Bonus.set(amount)
	player.leaderstats.Coins.Value += l1() -- expect: luau-shield001
end)
