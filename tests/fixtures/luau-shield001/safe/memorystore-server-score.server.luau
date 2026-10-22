--!strict
-- Safe: weekly high scores in a MemoryStore sorted map (twin of the vulnerable
-- memorystore-sorted-map entry). The score of a run is counted on the server
-- when the character touches checkpoints; the client only says that it wants
-- to submit its finished run. A cooldown limits MemoryStore requests (luau-shield007).

local CollectionService = game:GetService("CollectionService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SubmitRun = ReplicatedStorage.Remotes.SubmitRun :: RemoteEvent
local weeklyScores = MemoryStoreService:GetSortedMap("WeeklyHighScores")

local WEEK = 7 * 24 * 60 * 60
local SUBMIT_COOLDOWN = 10
local POINTS_PER_CHECKPOINT = 50

type Run = { score: number, finished: boolean }

local runs: { [Player]: Run } = {}
local lastSubmit: { [Player]: number } = {}

for _, checkpoint in CollectionService:GetTagged("Checkpoint") do
	local part = checkpoint :: BasePart
	part.Touched:Connect(function(hit: BasePart)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local run = if player then runs[player] else nil
		if run and not run.finished then
			run.score += POINTS_PER_CHECKPOINT
		end
	end)
end

SubmitRun.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastSubmit[player] or -math.huge) < SUBMIT_COOLDOWN then
		return
	end
	lastSubmit[player] = now

	local run = runs[player]
	if not run or run.finished then
		return
	end
	run.finished = true

	local score = run.score
	local ok, err = pcall(function()
		weeklyScores:UpdateAsync(tostring(player.UserId), function(best: number?): number?
			if best and best >= score then
				return nil
			end
			return score
		end, WEEK)
	end)
	if not ok then
		warn(`Could not submit the run of {player.Name}: {err}`)
	end
end)

Players.PlayerAdded:Connect(function(player)
	runs[player] = { score = 0, finished = false }
end)
