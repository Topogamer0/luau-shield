-- Safe (v0.2.0 review): the state is read into a local before the test.
-- Safe: same as the docs' LeaveGame example, but the state is read into a
-- local before the test.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Saves")
local LeaveGame = ReplicatedStorage.Remotes.LeaveGame
local state = {}

local function save(old)
	return old
end

LeaveGame.OnServerEvent:Connect(function(player)
	local current = state[player]
	if current ~= "Playing" then
		return
	end
	state[player] = "Menu"
	store:UpdateAsync(player.UserId, save)
end)
