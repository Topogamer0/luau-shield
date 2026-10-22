--!strict
-- Safe: renaming a pet. The pet id is used as a key of the saved data, but it
-- must be a pet the player owns (a key of the server's copy of their data).
-- The nickname is a string of 1 to MAX_NICKNAME bytes, which is what luau-shield001
-- requires for strings written to data. The raw text is filtered with
-- TextService every time it is shown to someone, not here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenamePet = ReplicatedStorage.Remotes.RenamePet :: RemoteEvent

local MAX_NICKNAME = 20

type PlayerData = {
	Pets: { [string]: { Species: string, Level: number } },
	PetNicknames: { [string]: string },
}

local sessions: { [Player]: PlayerData } = {}

RenamePet.OnServerEvent:Connect(function(player: Player, petId: unknown, nickname: unknown)
	local data = sessions[player]
	if not data or typeof(petId) ~= "string" or not data.Pets[petId] then
		return
	end
	if typeof(nickname) ~= "string" or #nickname == 0 or #nickname > MAX_NICKNAME then
		return
	end
	data.PetNicknames[petId] = nickname
end)

Players.PlayerAdded:Connect(function(player)
	sessions[player] = { Pets = {}, PetNicknames = {} }
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)
