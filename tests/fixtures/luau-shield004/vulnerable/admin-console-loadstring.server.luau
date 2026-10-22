--!strict
-- Vulnerable: a debug console left in the game. Any exploiter can fire
-- RunCode with arbitrary source and run it with server privileges (delete
-- the map, give themselves items, ban players, steal DataStore data).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunCode = ReplicatedStorage.Remotes.RunCode :: RemoteEvent

RunCode.OnServerEvent:Connect(function(player: Player, source: string)
	local chunk, err = loadstring(source) -- expect: luau-shield004
	if not chunk then
		warn(`[console] {player.Name}: {err}`)
		return
	end
	chunk()
end)
