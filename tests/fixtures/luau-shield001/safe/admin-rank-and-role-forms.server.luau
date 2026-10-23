-- Safe (v0.2.0 review): group rank in a local, `~= 255`, a staff role and the creator id (info).
-- The group rank is read once into a local, then compared.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GROUP_ID = 4567890
local ADMIN_RANK = 250
local data = {}

ReplicatedStorage.Remotes.AdminSetCoinsA.OnServerEvent:Connect(function(player, userId, coins)
	local rank = player:GetRankInGroup(GROUP_ID)
	if rank < ADMIN_RANK then
		return
	end
	data[userId].Coins = coins
end)

ReplicatedStorage.Remotes.AdminSetCoinsB.OnServerEvent:Connect(function(player, userId, coins)
	if player:GetRankInGroup(GROUP_ID) < ADMIN_RANK then
		return
	end
	data[userId].Coins = coins
end)

ReplicatedStorage.Remotes.AdminSetCoinsC.OnServerEvent:Connect(function(player, userId, coins)
	local isOwner = player.UserId == game.CreatorId
	if not isOwner then
		return
	end
	data[userId].Coins = coins
end)

ReplicatedStorage.Remotes.AdminSetCoinsD.OnServerEvent:Connect(function(player, userId, coins)
	if player:GetRoleInGroup(GROUP_ID) ~= "Owner" then
		return
	end
	data[userId].Coins = coins
end)

ReplicatedStorage.Remotes.AdminSetCoinsE.OnServerEvent:Connect(function(player, userId, coins)
	if player:GetRankInGroup(GROUP_ID) ~= 255 then
		return
	end
	data[userId].Coins = coins
end)
