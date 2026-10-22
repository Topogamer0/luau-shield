--!strict
-- Vulnerable: coin-flip minigame. The bet looks fully checked (type, > 0,
-- <= balance), but every check is written as "reject when the comparison is
-- true". Every comparison with NaN is false, so NaN passes all of them.
--
-- Exploit: fire CoinFlip with 0/0. data.Cash becomes NaN; from then on every
-- `price > data.Cash` check in the shop is false, so everything is free.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinFlip = ReplicatedStorage.Remotes.CoinFlip :: RemoteEvent

type Session = { Cash: number }

local sessions: { [Player]: Session } = {}

Players.PlayerAdded:Connect(function(player)
	sessions[player] = { Cash = 100 }
end)

CoinFlip.OnServerEvent:Connect(function(player: Player, bet: number)
	local data = sessions[player]
	if not data then
		return
	end
	if typeof(bet) ~= "number" or bet <= 0 or bet > data.Cash then
		return
	end

	data.Cash -= bet -- expect: luau-shield001
	if math.random() < 0.5 then
		data.Cash += bet * 2 -- expect: luau-shield001
	end
end)
