-- Vulnerable twice: the server waits on the client (luau-shield006) and then
-- trusts the bid the client returns, subtracting it from the coins without
-- any check (negative bids add coins, NaN corrupts the balance).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AskBid = ReplicatedStorage.Remotes.AskBid :: RemoteFunction

local function collectBid(player: Player)
	local bid = AskBid:InvokeClient(player) -- expect: luau-shield006
	player.leaderstats.Coins.Value -= bid -- expect: luau-shield001
end

Players.PlayerAdded:Connect(function(player)
	task.wait(30)
	collectBid(player)
end)
