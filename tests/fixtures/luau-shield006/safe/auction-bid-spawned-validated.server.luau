--!strict
-- Safe: the auction asks for the bid in a detached thread (the named function
-- is passed to task.spawn), so PlayerAdded never waits on the client. The bid
-- is client data: it must be a number, not NaN, at least 1 and at most the
-- player's coins before it is subtracted.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AskBid = ReplicatedStorage.Remotes.AskBid :: RemoteFunction

local function collectBid(player: Player)
	local bid = AskBid:InvokeClient(player)
	local coins = player.leaderstats.Coins
	if typeof(bid) ~= "number" or bid ~= bid then
		return -- not a number, or NaN
	end
	if bid < 1 or bid > coins.Value then
		return
	end
	coins.Value -= bid
end

Players.PlayerAdded:Connect(function(player: Player)
	task.wait(30)
	task.spawn(collectBid, player)
end)
