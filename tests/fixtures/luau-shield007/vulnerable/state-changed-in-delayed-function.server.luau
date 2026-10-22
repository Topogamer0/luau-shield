-- Vulnerable (v0.2.0 review): the state is only changed by a delayed function, after other requests passed the test.
-- "Teleporting in 5 seconds": the state is tested now, but changed only
-- inside the task.delay callback, 5 seconds later. Every Join request fired
-- during those 5 seconds passes the test and schedules its own
-- TeleportOptions + TeleportAsync: a client firing Join in a loop queues
-- thousands of teleport calls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Join = ReplicatedStorage.Remotes.Join
local Countdown = ReplicatedStorage.Remotes.Countdown
local ARENA_PLACE = 1234567
local state: { [Player]: string } = {}

Join.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	if state[player] ~= "Lobby" then
		return
	end
	Countdown:FireClient(player, 5)
	task.delay(5, function()
		state[player] = "Teleporting"
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({ from = "lobby" })
		TeleportService:TeleportAsync(ARENA_PLACE, { player }, options)
	end)
end)
