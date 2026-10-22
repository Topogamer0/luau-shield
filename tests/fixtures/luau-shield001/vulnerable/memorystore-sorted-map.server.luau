--!strict
-- Vulnerable: weekly high scores kept in a MemoryStore sorted map. The client
-- computes its own score and submits it; t.number only proves it is a number.
--
-- Exploit: fire SubmitScore with 1e308 to take first place on every server's
-- leaderboard for the week.

local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local SubmitScore = ReplicatedStorage.Remotes.SubmitScore :: RemoteEvent
local weeklyScores = MemoryStoreService:GetSortedMap("WeeklyHighScores")

local WEEK = 7 * 24 * 60 * 60
local SUBMIT_COOLDOWN = 5
local lastSubmit: { [Player]: number } = {}

SubmitScore.OnServerEvent:Connect(function(player: Player, score: number)
	local now = workspace:GetServerTimeNow()
	if now - (lastSubmit[player] or 0) < SUBMIT_COOLDOWN then
		return
	end
	lastSubmit[player] = now

	if not t.number(score) then
		return
	end
	weeklyScores:SetAsync(tostring(player.UserId), score, WEEK) -- expect: luau-shield001
end)
