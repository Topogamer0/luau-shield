local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local AdminRanks = require(ServerScriptService.AdminRanks)
local data = {}

local COMMANDS = {
	give = {
		rank = 3,
		run = function(player, targetName, amount)
			local target = Players:FindFirstChild(targetName)
			if target then
				data[target].Coins += tonumber(amount)
			end
		end,
	},
	kick = {
		rank = 2,
		run = function(player, targetName, reason)
			local target = Players:FindFirstChild(targetName)
			if target then
				target:Kick(reason)
			end
		end,
	},
}

ReplicatedStorage.Remotes.AdminCommand.OnServerEvent:Connect(function(player, name, ...)
	local command = COMMANDS[name]
	if not command then
		return
	end
	if AdminRanks.getRank(player) < command.rank then
		return
	end
	command.run(player, ...)
end)

-- Fixed level for the panel.
ReplicatedStorage.Remotes.PanelSetCoins.OnServerEvent:Connect(function(player, targetName, amount)
	if AdminRanks.getRank(player) < 3 then
		return
	end
	local target = Players:FindFirstChild(targetName)
	if target then
		data[target].Coins = amount
	end
end)
