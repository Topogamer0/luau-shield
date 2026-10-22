-- Vulnerable (v0.2.0 review): the admin branch is info, the player branch deletes any build.
-- One "Interact" remote: admins inspect a player's stats, everyone else
-- deletes the build they clicked on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Admins = require(ServerScriptService.Admins)
local data = {}

ReplicatedStorage.Remotes.Interact.OnServerEvent:Connect(function(player, target)
	if Admins.isAdmin(player) then
		data[player].DebugCoins = target.leaderstats.Coins.Value
		return
	end
	target:Destroy() -- expect: luau-shield003
end)
