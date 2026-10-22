-- Vulnerable: at the end of each round the server asks every client how many
-- points it scored (hits are detected on the client "to avoid lag") and adds
-- the answer to leaderstats. Each call runs in task.spawn, so a client that
-- never answers cannot stall the round loop (no luau-shield006), but the value
-- returned by InvokeClient is still whatever the client wants it to be.
--
-- Exploit: in an executor, set GetRoundScore.OnClientInvoke to a function
-- that returns 1e9 and win every round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GetRoundScore = ReplicatedStorage.Remotes.GetRoundScore :: RemoteFunction
local RoundEnded = ServerStorage.Events.RoundEnded :: BindableEvent

local function rewardRound()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			local score = GetRoundScore:InvokeClient(player)
			local leaderstats = player:FindFirstChild("leaderstats")
			if typeof(score) == "number" and leaderstats then
				leaderstats.Score.Value += score -- expect: luau-shield001
			end
		end)
	end
end

RoundEnded.Event:Connect(rewardRound)
