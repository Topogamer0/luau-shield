-- Vulnerable: tasks are registered in `shared` (Roblox's cross-VM global table,
-- a sibling of _G) and dispatched by a name the client sends. Any function that
-- any server script stored in `shared` becomes callable by every exploiter,
-- with arguments of their choosing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

shared.KickIdlePlayers = function(_player: Player)
	-- privileged housekeeping meant to run only from an admin dashboard
end

local RunTask = ReplicatedStorage.Remotes.RunTask :: RemoteEvent

RunTask.OnServerEvent:Connect(function(player: Player, taskName: string, ...: any)
	shared[taskName](player, ...) -- expect: luau-shield004
end)
