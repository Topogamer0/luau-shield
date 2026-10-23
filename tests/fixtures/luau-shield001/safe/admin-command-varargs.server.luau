-- Safe (v0.2.0 review): admin command arguments passed as varargs after the permission check (info).
-- Admin panel: one remote, the command name and its arguments.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local data = {}

ReplicatedStorage.Remotes.AdminCommand.OnServerEvent:Connect(function(player, command, ...)
	if not Admins.isAdmin(player) then
		return
	end
	local args = { ... }
	if command == "setcoins" then
		data[args[1]].Coins = args[2]
	end
end)
