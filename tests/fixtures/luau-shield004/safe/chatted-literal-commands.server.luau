-- Safe: chat commands are compared with fixed strings and dispatched to
-- server functions; the message itself is never executed.
local Players = game:GetService("Players")

local function resetCharacter(player: Player)
	player:LoadCharacter()
end

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(message: string)
		local command = string.lower(message)
		if command == "/reset" then
			resetCharacter(player)
		elseif command == "/help" then
			print(`{player.Name} asked for help`)
		end
	end)
end)
