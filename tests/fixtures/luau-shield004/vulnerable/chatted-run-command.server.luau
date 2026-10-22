-- Vulnerable: a chat command runs whatever follows "/run ". Chat messages are
-- typed by the player, so every player can execute code on the server.
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player: Player)
	player.Chatted:Connect(function(message: string)
		if message:sub(1, 5) ~= "/run " then
			return
		end
		local code = message:sub(6)
		local chunk = loadstring(code) -- expect: luau-shield004
		if chunk then
			task.spawn(chunk)
		end
	end)
end)
