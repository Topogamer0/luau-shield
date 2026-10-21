-- Coin gifts between players. The receiver confirms the offer in a prompt
-- on their screen before any coins move.

local Players = game:GetService("Players")

local Economy = require(script.Parent.Modules.Economy)
local Remotes = require(script.Parent.Modules.Remotes)

local busy: { [Player]: boolean } = {}

Remotes.OfferTrade.OnServerEvent:Connect(function(player: Player, targetUserId: number, coins: number)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player or busy[target] then
		return
	end
	if Economy.getCoins(player) < coins then
		return -- cannot offer more than you have
	end

	-- Ask the receiver and wait for the answer.
	busy[target] = true
	local accepted = Remotes.ConfirmTrade:InvokeClient(target, player.Name, coins)
	busy[target] = nil
	if accepted ~= true then
		return
	end

	if Economy.trySpend(player, coins) then
		Economy.addCoins(target, coins)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
