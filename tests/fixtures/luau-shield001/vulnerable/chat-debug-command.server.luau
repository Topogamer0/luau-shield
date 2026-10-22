--!strict
-- Vulnerable: a "/givecash" chat command used while testing was left in the
-- live game. The amount comes from the chat message, which the player types
-- (player.Chatted is a client-controlled source), and tonumber only proves
-- that the text is a number.
--
-- Exploit: no executor needed. Any player types "/givecash 1e15" in chat.

local Players = game:GetService("Players")

type Data = { Cash: number, Wins: number }

local PlayerData: { [Player]: Data } = {}

local function onChatted(player: Player, message: string)
	local args = string.split(message, " ")
	if args[1] ~= "/givecash" or not PlayerData[player] then
		return
	end
	local amount = tonumber(args[2])
	if not amount then
		return
	end
	PlayerData[player].Cash += amount -- expect: luau-shield001
end

Players.PlayerAdded:Connect(function(player)
	PlayerData[player] = { Cash = 0, Wins = 0 }
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData[player] = nil
end)
