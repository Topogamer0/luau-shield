-- Safe: a busy flag per player: while a teleport is in progress, further
-- requests are ignored.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local ARENA_PLACE_ID = 1234567890
local busy: { [Player]: boolean } = {}

ReplicatedStorage.Remotes.Play.OnServerEvent:Connect(function(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(ARENA_PLACE_ID, { player })
	end)
	if not ok then
		warn(err)
	end
	busy[player] = nil
end)
