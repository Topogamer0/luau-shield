-- Vulnerable: a trade request asks the other player to confirm with
-- InvokeClient. The target (or an exploiter acting as target) can hang the
-- requesting player's trade forever.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage.Remotes
local ConfirmTrade = Remotes.ConfirmTrade :: RemoteFunction

Remotes.RequestTrade.OnServerEvent:Connect(function(player: Player, targetUserId: number)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	local accepted = ConfirmTrade:InvokeClient(target, player.Name) -- expect: luau-shield006
	print(`trade {player.Name} -> {target.Name}: {accepted}`)
end)
