-- Vulnerable: a map vote asks every player in turn. One exploiter that never
-- answers blocks the vote (and the round loop) for everyone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AskVote = ReplicatedStorage.Remotes.AskVote :: RemoteFunction
local MAPS = { "Desert", "Forest", "City" }

local function runVote(): string
	local votes: { [string]: number } = {}
	for _, player in Players:GetPlayers() do
		local choice = AskVote:InvokeClient(player, MAPS) -- expect: luau-shield006
		if typeof(choice) == "string" and table.find(MAPS, choice) then
			votes[choice] = (votes[choice] or 0) + 1
		end
	end
	local best, bestCount = MAPS[1], -1
	for map, count in votes do
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
