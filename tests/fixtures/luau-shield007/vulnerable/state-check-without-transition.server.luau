-- Vulnerable: the handler checks the state but never changes it, so a player
-- who is "Playing" can fire LeaveGame in a loop and every request saves.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Saves")
local remote = ReplicatedStorage.Remotes
local state = {}

local function save(old)
	return old
end

remote.LeaveGame.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	if state[player] ~= "Playing" then return end
	store:UpdateAsync(player.UserId, save)
end)
