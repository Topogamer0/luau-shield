--!strict
-- Team selection screen: the client shows one button per joinable team and
-- sends the TeamColor of the button that was clicked.
--
-- Exploit: send BrickColor.new("Really black"), the colour of the hidden
-- "Staff" team. The exploiter joins it, spawns on the staff SpawnLocation and
-- walks through every team-only door. typeof only proves it is a BrickColor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChooseTeam = ReplicatedStorage.Remotes.ChooseTeam :: RemoteEvent

ChooseTeam.OnServerEvent:Connect(function(player: Player, color: BrickColor)
	if typeof(color) ~= "BrickColor" then
		return
	end

	player.Neutral = false
	player.TeamColor = color -- expect: luau-shield002
	player:LoadCharacter()
end)
