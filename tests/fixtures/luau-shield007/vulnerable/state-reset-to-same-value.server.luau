-- Vulnerable: the state is written back with the value that passes the check
-- ("Playing" stays "Playing"), so the guard never closes.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Saves")
local remote = ReplicatedStorage.Remotes
local state = {}

local function save(old)
	return old
end

remote.Checkpoint.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	if state[player] ~= "Playing" then return end
	state[player] = "Playing"
	store:UpdateAsync(player.UserId, save)
end)
