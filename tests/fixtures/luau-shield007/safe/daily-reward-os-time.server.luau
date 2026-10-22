--!strict
-- Safe: the daily reward is limited with os.time(). The last claim time is
-- loaded when the player joins and checked before the DataStore write, so
-- spamming ClaimDaily costs at most one SetAsync per player per day.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DAY = 24 * 60 * 60
local DAILY_COINS = 250
local dailyStore = DataStoreService:GetDataStore("DailyReward")
local lastClaim: { [Player]: number } = {}

Players.PlayerAdded:Connect(function(player: Player)
	local ok, saved = pcall(function()
		return dailyStore:GetAsync(tostring(player.UserId))
	end)
	if ok then
		lastClaim[player] = if typeof(saved) == "number" then saved else 0
	end
end)

ReplicatedStorage.Remotes.ClaimDaily.OnServerEvent:Connect(function(player: Player)
	local last = lastClaim[player]
	local now = os.time()
	if not last or now - last < DAY then
		return
	end
	lastClaim[player] = now
	player.leaderstats.Coins.Value += DAILY_COINS
	pcall(function()
		dailyStore:SetAsync(tostring(player.UserId), now)
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastClaim[player] = nil
end)
