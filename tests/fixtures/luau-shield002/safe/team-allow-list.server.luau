--!strict
-- Team selection, fixed: the client sends a team name and the server maps it
-- to a Team through JOINABLE_TEAMS, a server table that only contains the
-- teams players may join (the hidden Staff team is not in it). The TeamName
-- type documents the expected values but is not a check; the lookup is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

type TeamName = "Red" | "Blue"

local JOINABLE_TEAMS: { [TeamName]: Team } = {
	Red = Teams:WaitForChild("Red") :: Team,
	Blue = Teams:WaitForChild("Blue") :: Team,
}

local ChooseTeam = ReplicatedStorage.Remotes.ChooseTeam :: RemoteEvent

ChooseTeam.OnServerEvent:Connect(function(player: Player, teamName: TeamName)
	local team = JOINABLE_TEAMS[teamName]
	if not team or player.Team == team then
		return
	end

	player.Neutral = false
	player.Team = team
	player:LoadCharacter()
end)
