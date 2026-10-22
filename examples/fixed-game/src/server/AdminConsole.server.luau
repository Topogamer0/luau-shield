-- Developer tools: admin commands from the HUD console and from chat.
-- There is no code execution: only the commands listed in COMMANDS exist,
-- and only the user ids in ADMINS (kept on the server) can run them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Validate = require(ReplicatedStorage.Shared.Validate)
local Economy = require(script.Parent.Modules.Economy)
local Remotes = require(script.Parent.Modules.Remotes)

local ADMINS: { [number]: boolean } = {
	[1234567] = true, -- game owner
	[7654321] = true, -- moderator
}

local COMMANDS: { [string]: (admin: Player, argument: string) -> () } = {
	heal = function(admin)
		local character = admin.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end,
	givecoins = function(admin, argument)
		local amount = tonumber(argument)
		if Validate.isIntegerInRange(amount, 1, 1_000_000) then
			Economy.addCoins(admin, amount)
		end
	end,
	kick = function(admin, argument)
		local target = Players:GetPlayerByUserId(tonumber(argument) or 0)
		if target and not ADMINS[target.UserId] then
			target:Kick(`Removed by {admin.Name}`)
		end
	end,
}

local function runCommand(player: Player, name: unknown, argument: unknown)
	if not ADMINS[player.UserId] or typeof(name) ~= "string" or typeof(argument) ~= "string" then
		return
	end
	local command = COMMANDS[name:lower()]
	if command then
		command(player, argument)
	end
end

-- Console: AdminCommand:FireServer("givecoins", "500")
Remotes.AdminCommand.OnServerEvent:Connect(runCommand)

-- Chat: ";givecoins 500"
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local name, argument = string.match(message, "^;(%a+)%s*(.-)$")
		if name then
			runCommand(player, name, argument)
		end
	end)
end)
