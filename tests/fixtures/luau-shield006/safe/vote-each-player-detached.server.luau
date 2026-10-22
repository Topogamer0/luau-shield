--!strict
-- Safe: the map vote asks every player at the same time, each in its own
-- task.spawn thread, and the round only waits a fixed VOTE_TIME. A player
-- that never answers simply does not vote (and is not asked again while the
-- old question is pending); answers are allow-listed against MAPS.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AskVote = ReplicatedStorage.Remotes.AskVote :: RemoteFunction
local MAPS = { "Desert", "Forest", "City" }
local VOTE_TIME = 15

local waiting: { [Player]: boolean } = {}

local function runVote(): string
	local votes: { [Player]: string } = {}
	for _, player in Players:GetPlayers() do
		if waiting[player] then
			continue
		end
		waiting[player] = true
		task.spawn(function()
			local ok, choice = pcall(AskVote.InvokeClient, AskVote, player, MAPS)
			waiting[player] = nil
			if ok and typeof(choice) == "string" and table.find(MAPS, choice) then
				votes[player] = choice
			end
		end)
	end
	task.wait(VOTE_TIME)
	local counts: { [string]: number } = {}
	for _, map in votes do
		counts[map] = (counts[map] or 0) + 1
	end
	local best, bestCount = MAPS[1], 0
	for map, count in counts do
		if count > bestCount then
			best, bestCount = map, count
		end
	end
	return best
end

while true do
	task.wait(60)
	print("Next map:", runVote())
end
