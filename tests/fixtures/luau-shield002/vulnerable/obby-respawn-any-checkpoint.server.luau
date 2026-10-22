--!strict
-- Obby checkpoint menu: players can respawn at any checkpoint they have
-- already reached. The menu sends the SpawnLocation that was clicked and the
-- server makes it the player's RespawnLocation. IsA proves that the client
-- sent a SpawnLocation, not that the player has reached it.
--
-- Exploit: every client can see workspace.Checkpoints, so send the
-- SpawnLocation of the last stage (or the spawn of another team) and respawn
-- there: the whole obby is skipped and the completion reward is collected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectCheckpoint = ReplicatedStorage.Remotes.SelectCheckpoint :: RemoteEvent

SelectCheckpoint.OnServerEvent:Connect(function(player: Player, checkpoint: SpawnLocation)
	if typeof(checkpoint) ~= "Instance" or not checkpoint:IsA("SpawnLocation") then
		return
	end

	player.RespawnLocation = checkpoint -- expect: luau-shield002
	player:LoadCharacter()
end)
