--!strict
-- Vulnerable: Wave has a cooldown, but RateGame, written next to it, has
-- none. A rate limit only protects the handler it is in: an exploiter spams
-- RateGame and every request is an HTTP call to the team's feedback API,
-- using up the server's HttpService budget.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Remotes = ReplicatedStorage.Remotes
local FEEDBACK_URL = "https://feedback.example.com/v1/ratings"
local lastWave: { [Player]: number } = {}

Remotes.Wave.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastWave[player] or -math.huge) < 3 then
		return
	end
	lastWave[player] = now
	local head = player.Character and player.Character:FindFirstChild("Head")
	if head then
		ServerStorage.Effects.WaveSparkles:Clone().Parent = head
	end
end)

Remotes.RateGame.OnServerEvent:Connect(function(player: Player, stars: unknown) -- expect: luau-shield007
	if typeof(stars) ~= "number" or stars ~= stars or stars < 1 or stars > 5 then
		return
	end
	local body = HttpService:JSONEncode({ userId = player.UserId, stars = math.floor(stars) })
	HttpService:PostAsync(FEEDBACK_URL, body)
end)
