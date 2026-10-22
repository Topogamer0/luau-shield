--!strict
-- Vulnerable: the "timeout" runs in the wrong thread. task.delay only warns
-- after 5 seconds, while the PlayerAdded thread itself is still parked inside
-- InvokeClient: an exploiter that never answers keeps it suspended until they
-- leave, and a client that errors makes InvokeClient throw, so the class is
-- never assigned. Only the code passed to task.delay is detached.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PickClass = ReplicatedStorage.Remotes.PickClass :: RemoteFunction
local CLASSES = { "Knight", "Archer", "Mage" }
local TIMEOUT = 5

Players.PlayerAdded:Connect(function(player: Player)
	local answered = false
	task.delay(TIMEOUT, function()
		if not answered then
			warn(`{player.Name} did not pick a class in time`)
		end
	end)
	local class = PickClass:InvokeClient(player, CLASSES) -- expect: luau-shield006
	answered = true
	if typeof(class) == "string" and table.find(CLASSES, class) then
		player:SetAttribute("Class", class)
	else
		player:SetAttribute("Class", CLASSES[1])
	end
end)
