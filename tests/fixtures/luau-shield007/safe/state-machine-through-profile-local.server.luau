-- Safe (v0.2.0 review): state machines on a profile read into a local.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local store = DataStoreService:GetDataStore("Saves")
local profiles = {}
local R = ReplicatedStorage.Remotes
-- A: state field of a profile read into a local
R.A.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if profile.State ~= "Playing" then
		return
	end
	profile.State = "Menu"
	store:UpdateAsync(player.UserId, function(old) return old end)
end)
-- B: constant slot through the local
R.B.OnServerEvent:Connect(function(player)
	local profile = profiles[player]
	if profile.Slots[1] then
		profile.Slots[1] = nil
		store:UpdateAsync(player.UserId, function(old) return old end)
	end
end)
-- C: validated slot through the local
R.C.OnServerEvent:Connect(function(player, slot)
	if typeof(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > 3 then return end
	local profile = profiles[player]
	if profile and profile.Slots[slot] then
		profile.Slots[slot] = nil
		store:UpdateAsync(player.UserId, function(old) return old end)
	end
end)
