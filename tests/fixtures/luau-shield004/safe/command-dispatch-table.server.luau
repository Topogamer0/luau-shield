--!strict
-- Safe: the client only chooses the NAME of a command; the code that runs is a
-- server-side function from a fixed table.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Command = (player: Player) -> ()

local Commands: { [string]: Command } = {
	sit = function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = true
		end
	end,
	respawn = function(player)
		player:LoadCharacter()
	end,
}

ReplicatedStorage.Remotes.RunCommand.OnServerEvent:Connect(function(player: Player, name: string)
	local command = Commands[name]
	if not command then
		return
	end
	command(player)
end)
