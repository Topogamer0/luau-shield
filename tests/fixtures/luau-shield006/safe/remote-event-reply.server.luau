--!strict
-- Safe: the trade confirmation uses two RemoteEvents. The server asks with
-- FireClient and accepts the answer on another remote; pending requests
-- expire on the server, nothing ever waits on the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage.Remotes
local TradeRequest = Remotes.TradeRequest :: RemoteEvent
local TradeAnswer = Remotes.TradeAnswer :: RemoteEvent

local pending: { [Player]: { from: Player, expires: number } } = {}

Remotes.RequestTrade.OnServerEvent:Connect(function(player: Player, targetUserId: number)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or pending[target] then
		return
	end
	pending[target] = { from = player, expires = os.clock() + 15 }
	TradeRequest:FireClient(target, player.Name)
end)

TradeAnswer.OnServerEvent:Connect(function(player: Player, accepted: boolean)
	local request = pending[player]
	if not request or typeof(accepted) ~= "boolean" then
		return
	end
	pending[player] = nil
	if os.clock() > request.expires then
		return
	end
	print(`trade {request.from.Name} -> {player.Name}: {if accepted then "accepted" else "declined"}`)
end)
