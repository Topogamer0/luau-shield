--!strict
-- Obby checkpoint menu, fixed: the SpawnLocation sent by the client must be a
-- direct child of the Checkpoints folder (a location check) and its Stage
-- attribute must not be past the stage the player has reached, which the
-- server keeps in leaderstats. Respawns have a cooldown, because
-- LoadCharacter is expensive.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectCheckpoint = ReplicatedStorage.Remotes.SelectCheckpoint :: RemoteEvent
local Checkpoints = workspace:WaitForChild("Checkpoints")

local RESPAWN_COOLDOWN = 3
local lastRespawn: { [Player]: number } = {}

SelectCheckpoint.OnServerEvent:Connect(function(player: Player, checkpoint: SpawnLocation)
	local leaderstats = player:FindFirstChild("leaderstats")
	local reached = if leaderstats then leaderstats:FindFirstChild("Stage") :: IntValue? else nil
	if not reached or typeof(checkpoint) ~= "Instance" or checkpoint.Parent ~= Checkpoints then
		return
	end

	local stage = checkpoint:GetAttribute("Stage")
	if not checkpoint:IsA("SpawnLocation") or typeof(stage) ~= "number" or stage > reached.Value then
		return
	end

	local now = os.clock()
	if now - (lastRespawn[player] or 0) < RESPAWN_COOLDOWN then
		return
	end
	lastRespawn[player] = now

	player.RespawnLocation = checkpoint
	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastRespawn[player] = nil
end)
