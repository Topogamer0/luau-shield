--!strict
-- Safe: coin-flip minigame (twin of the vulnerable nan-bypass entry). The bet
-- guard also rejects NaN with `bet ~= bet`, so the value that reaches the
-- writes is a number in (0, data.Cash]. The payout reuses the checked bet.

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
	if typeof(bet) ~= "number" or bet ~= bet or bet <= 0 or bet > data.Cash then
		return
	end

	local won = math.random() < 0.5
	if won then
		data.Cash += bet
	else
		data.Cash -= bet
	end
end)
