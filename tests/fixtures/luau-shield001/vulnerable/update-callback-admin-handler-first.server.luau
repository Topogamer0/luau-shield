-- Vulnerable (v0.2.0 review): a callback shared by an admin handler and a public one is analysed for both.
-- ProfileService/DataManager style: writes go through an update callback
-- passed to a library method luau-shield cannot resolve. The admin panel and
-- the public reward share `addCoins`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local DataManager = require(ServerScriptService.DataManager)

local function addCoins(player, amount)
	DataManager:Update(player, function(profile)
		profile.Data.Coins += amount -- expect: luau-shield001
	end)
end

ReplicatedStorage.Remotes.AdminGive.OnServerEvent:Connect(function(player, amount)
	if not Admins.isAdmin(player) then
		return
	end
	addCoins(player, amount)
end)

ReplicatedStorage.Remotes.ClaimDaily.OnServerEvent:Connect(function(player, amount)
	addCoins(player, amount)
end)
