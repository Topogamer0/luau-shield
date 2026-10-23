-- Vulnerable (v0.2.0 review): a yield in a function past the call depth, between the test and the change.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local store = DataStoreService:GetDataStore("Queue")
local Join = ReplicatedStorage.Remotes.Join
local Loaded = {}
local state = {}

local function f6(p)
	while not Loaded[p] do
		task.wait(0.5)
	end
	return true
end

local function f5(p)
	return f6(p)
end

local function f4(p)
	return f5(p)
end

local function f3(p)
	return f4(p)
end

local function f2(p)
	return f3(p)
end

local function f1(p)
	return f2(p)
end

Join.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	if state[player] ~= "Lobby" then
		return
	end
	if not f1(player) then
		return
	end
	state[player] = "Queued"
	store:SetAsync(tostring(player.UserId), "Queued")
end)
