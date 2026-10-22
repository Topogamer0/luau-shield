-- Limitation: data relayed through a BindableEvent is not followed.
-- The remote handler forwards the client's amount to another script through
-- a BindableEvent; the listener adds it to the player's coins. Ideally the
-- write would be reported (the amount is client-controlled), but signals are
-- not followed, so luau-shield misses it (false negative).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local rewardSignal = ServerStorage.Signals.Reward :: BindableEvent

ReplicatedStorage.Remotes.ClaimReward.OnServerEvent:Connect(function(player: Player, amount: number)
	rewardSignal:Fire(player, amount)
end)

rewardSignal.Event:Connect(function(player: Player, amount: number)
	player.leaderstats.Coins.Value += amount -- expect: luau-shield001
end)
