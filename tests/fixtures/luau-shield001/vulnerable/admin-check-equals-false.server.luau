-- Vulnerable (v0.2.0 review): `isAdmin(player) == false` lets players through when it returns nil.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local data = {}
ReplicatedStorage.Remotes.AdminGive.OnServerEvent:Connect(function(player, amount)
	if Admins.isAdmin(player) == false then
		return
	end
	data[player].Coins += amount -- expect: luau-shield001
end)
