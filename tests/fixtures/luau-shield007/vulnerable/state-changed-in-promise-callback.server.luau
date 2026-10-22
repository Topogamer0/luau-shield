-- Vulnerable (v0.2.0 review): the state is only changed in a Promise `andThen` callback.
-- Knit-style code: the state is tested now, but changed in a Promise
-- `:andThen` callback that runs only when the profile promise resolves
-- (after a yield). Every Join request fired before the first promise
-- resolves passes the test and queues its own DataStore write.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local queueStore = DataStoreService:GetDataStore("Queue")
local Join = ReplicatedStorage.Remotes.Join
local Profiles: { [Player]: any } = {}
local state: { [Player]: string } = {}

local function getProfile(player: Player)
	return Promise.new(function(resolve, reject)
		while not Profiles[player] and player.Parent do
			task.wait(0.1)
		end
		if Profiles[player] then
			resolve(Profiles[player])
		else
			reject("left")
		end
	end)
end

Join.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	if state[player] ~= "Lobby" then
		return
	end
	getProfile(player):andThen(function(profile)
		state[player] = "Queued"
		queueStore:SetAsync(tostring(player.UserId), profile.Data.Rating)
	end)
end)
