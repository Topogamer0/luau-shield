-- Safe (v0.2.0 review): admin tools act on Instances the admin picked (info).
-- Admin panel: admins kick or remove a player's build. Only admins pass
-- the check, so the client-chosen target is fine here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Admins = require(ServerScriptService.Admins)

ReplicatedStorage.Remotes.AdminKick.OnServerEvent:Connect(function(player, target, reason)
	if not Admins.isAdmin(player) then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end
	target:Kick(tostring(reason))
end)

ReplicatedStorage.Remotes.AdminDeleteBuild.OnServerEvent:Connect(function(player, build)
	if not Admins.isAdmin(player) then
		return
	end
	if typeof(build) ~= "Instance" then
		return
	end
	build:Destroy()
end)

ReplicatedStorage.Remotes.AdminBring.OnServerEvent:Connect(function(player, target)
	if not Admins.isAdmin(player) then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end
	target.Character:PivotTo(player.Character:GetPivot())
	target.Character.Humanoid.WalkSpeed = 16
end)
