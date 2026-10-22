-- Vulnerable: the lobby button calls a module that teleports the player to
-- a reserved server; each request calls two Async APIs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matchmaking = require(script.Parent.Modules.Matchmaking)

ReplicatedStorage.Remotes.Play.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	Matchmaking.send(player)
end)
