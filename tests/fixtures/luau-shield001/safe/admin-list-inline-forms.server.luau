-- Safe (v0.2.0 review): permission lists tested directly, through a local, or with `~= nil` (info).
-- Common spellings of the documented inline checks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ADMINS = { [12345] = true, [67890] = true }
local ADMIN_IDS = { 12345, 67890 }
local data = {}

ReplicatedStorage.Remotes.A.OnServerEvent:Connect(function(player, userId, coins)
	if ADMINS[player.UserId] ~= true then
		return
	end
	data[userId].A = coins
end)

ReplicatedStorage.Remotes.B.OnServerEvent:Connect(function(player, userId, coins)
	if table.find(ADMIN_IDS, player.UserId) == nil then
		return
	end
	data[userId].B = coins
end)

ReplicatedStorage.Remotes.C.OnServerEvent:Connect(function(player, userId, coins)
	local isAdmin = ADMINS[player.UserId]
	if not isAdmin then
		return
	end
	data[userId].C = coins
end)

ReplicatedStorage.Remotes.D.OnServerEvent:Connect(function(player, userId, coins)
	if not table.find(ADMIN_IDS, player.UserId) then
		return
	end
	data[userId].D = coins
end)

ReplicatedStorage.Remotes.E.OnServerEvent:Connect(function(player, userId, coins)
	if not ADMINS[player.UserId] then
		return
	end
	data[userId].E = coins
end)
