-- Safe (v0.2.0 review): deleting an existing pet through a local copy of the profile.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local deletedLog = DataStoreService:GetDataStore("DeletedPets")
local profiles = {}
local R = ReplicatedStorage.Remotes
-- 1: direct test on the entry, client id
R.Delete1.OnServerEvent:Connect(function(player, id)
	local data = profiles[player]
	if data and data.Pets[id] then
		data.Pets[id] = nil
		deletedLog:SetAsync(id, player.UserId)
	end
end)
-- 2: entry read into a local
R.Delete2.OnServerEvent:Connect(function(player, id)
	local data = profiles[player]
	if not data then return end
	local pet = data.Pets[id]
	if pet then
		data.Pets[id] = nil
		deletedLog:SetAsync(id, player.UserId)
	end
end)
-- 3: profiles[player].Pets[id] directly
R.Delete3.OnServerEvent:Connect(function(player, id)
	if profiles[player].Pets[id] then
		profiles[player].Pets[id] = nil
		deletedLog:SetAsync(id, player.UserId)
	end
end)
-- 4: string id validated
R.Delete4.OnServerEvent:Connect(function(player, id)
	if typeof(id) ~= "string" then return end
	if profiles[player].Pets[id] then
		profiles[player].Pets[id] = nil
		deletedLog:SetAsync(id, player.UserId)
	end
end)
