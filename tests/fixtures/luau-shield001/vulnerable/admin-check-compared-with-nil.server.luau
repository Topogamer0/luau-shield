-- Vulnerable (v0.2.0 review): `isAdmin(player) ~= nil` also holds when it returns false.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local data = {}
ReplicatedStorage.Remotes.Give.OnServerEvent:Connect(function(player, amount)
	if Admins.isAdmin(player) ~= nil then
		data[player].Coins += amount -- expect: luau-shield001
	end
end)
