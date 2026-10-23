-- Safe (luau-shield v0.2.0 report, case 4): the handler only saves while the
-- player is "Playing" and switches the state to "Menu" before the save, so a
-- second request is ignored until the player joins a game again.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Saves")
local remote = ReplicatedStorage.Remotes
local state = {}
local sessions = {}

local function save(old)
	return old
end

remote.JoinGame.OnServerEvent:Connect(function(player)
	if state[player] == "Playing" then return end
	state[player] = "Playing"
	sessions[player] = os.clock()
end)

remote.LeaveGame.OnServerEvent:Connect(function(player)
	if state[player] ~= "Playing" then return end
	state[player] = "Menu" -- the second request is ignored
	store:UpdateAsync(player.UserId, save)
end)
