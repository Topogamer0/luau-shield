-- Safe (v0.2.0 review): state names kept in a constant table.
-- Safe: the docs' LeaveGame state machine, with the state names kept in a
-- constant table (the usual way to avoid typos in state strings).
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("Saves")
local LeaveGame = ReplicatedStorage.Remotes.LeaveGame

local State = table.freeze({
	Menu = "Menu",
	Playing = "Playing",
})
local state: { [Player]: string } = {}

local function save(old)
	return old
end

LeaveGame.OnServerEvent:Connect(function(player: Player)
	if state[player] ~= State.Playing then
		return
	end
	state[player] = State.Menu -- a second request is ignored
	store:UpdateAsync(player.UserId, save)
end)
