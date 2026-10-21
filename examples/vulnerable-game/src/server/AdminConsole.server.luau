-- Developer tools: a hidden console in the HUD (unlocked with the admin
-- password) and chat commands for the admins of our group.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Modules.Remotes)

local GROUP_ID = 4821937
local ADMIN_RANK = 250

local function isAdmin(player: Player): boolean
	return player:GetRankInGroup(GROUP_ID) >= ADMIN_RANK
end

-- Runs the Luau code typed in the developer console.
Remotes.AdminCommand.OnServerEvent:Connect(function(player: Player, password: string, source: string)
	if password ~= Config.AdminPassword then
		warn(`{player.Name} sent a wrong console password`)
		return
	end
	local chunk, err = loadstring(source)
	if not chunk then
		warn(`Console error: {err}`)
		return
	end
	chunk()
end)

-- Chat command ";plugin <assetId>" loads one of our admin plugin modules.
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if not isAdmin(player) then
			return
		end
		local command, argument = string.match(message, "^;(%a+)%s+(.+)$")
		if command == "plugin" then
			local plugin = require(tonumber(argument))
			plugin.run(player)
		end
	end)
end)
