-- Vulnerable (v0.2.0 review): another remote lets any player add themselves to the admin list.
-- The admin list is filled at runtime by a remote that forgot its own
-- permission check (the admin panel only hides the button on the client).
-- Any exploiter adds themselves, then uses the "admin-only" remote.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local admins = {}
local adminIds = {}
local data = {}

Remotes.AddAdmin.OnServerEvent:Connect(function(player, userId)
	admins[userId] = true
	table.insert(adminIds, userId)
end)

Remotes.AdminGive.OnServerEvent:Connect(function(player, amount)
	if not admins[player.UserId] then
		return
	end
	data[player].Coins += amount -- expect: luau-shield001
end)

Remotes.AdminGive2.OnServerEvent:Connect(function(player, amount)
	if not table.find(adminIds, player.UserId) then
		return
	end
	data[player].Coins += amount -- expect: luau-shield001
end)
