-- Safe (v0.2.0 review): the state lives in a player attribute.
-- Safe: the matchmaking state is kept in a player attribute (so the client
-- UI can read it). Queue only from the lobby, and leave the lobby state
-- before teleporting: a second request returns early.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local JoinMatch = ReplicatedStorage.Remotes.JoinMatch
local MATCH_PLACE_ID = 1234567

JoinMatch.OnServerEvent:Connect(function(player)
	if player:GetAttribute("State") ~= "Lobby" then
		return
	end
	player:SetAttribute("State", "Teleporting")
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, MATCH_PLACE_ID, { player })
	if not ok then
		warn(err)
	end
end)
