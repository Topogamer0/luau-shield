--!strict
local TeleportService = game:GetService("TeleportService")

local ARENA_PLACE_ID = 1234567890

local Matchmaking = {}

function Matchmaking.send(player: Player)
	local code = TeleportService:ReserveServerAsync(ARENA_PLACE_ID)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	TeleportService:TeleportAsync(ARENA_PLACE_ID, { player }, options)
end

return Matchmaking
