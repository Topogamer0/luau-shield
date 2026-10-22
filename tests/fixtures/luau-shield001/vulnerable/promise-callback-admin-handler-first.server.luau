-- Vulnerable (v0.2.0 review): a Promise callback shared by an admin handler and a public one is analysed for both.
-- Same pattern with an unresolved Promise library: `Promise.new(fn)` runs
-- the executor; the admin handler is analysed first.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local Promise = require(ReplicatedStorage.Packages.Promise)
local data = {}

local function grant(player, amount)
	return Promise.new(function(resolve)
		data[player].Coins += amount -- expect: luau-shield001
		resolve()
	end)
end

ReplicatedStorage.Remotes.AdminGrant.OnServerEvent:Connect(function(player, amount)
	if not Admins.isAdmin(player) then
		return
	end
	grant(player, amount)
end)

ReplicatedStorage.Remotes.QuestReward.OnServerEvent:Connect(function(player, amount)
	grant(player, amount)
end)
