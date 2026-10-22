--!strict
-- Fast travel done right: the client sends the NAME of a checkpoint. The
-- server finds it in its own Checkpoints folder (a server lookup: the client
-- picks a key, not the value), checks that the player has unlocked it, and
-- teleports to the checkpoint's own CFrame. Looks like a client-driven
-- teleport, but the CFrame is server data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastTravel = ReplicatedStorage.Remotes.FastTravel :: RemoteEvent
local Checkpoints = workspace:WaitForChild("Checkpoints")

local unlocked: { [Player]: { [string]: boolean } } = {}

for _, checkpoint in Checkpoints:GetChildren() do
	if checkpoint:IsA("BasePart") then
		checkpoint.Touched:Connect(function(hit: BasePart)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local playerUnlocks = if player then unlocked[player] else nil
			if playerUnlocks then
				playerUnlocks[checkpoint.Name] = true
			end
		end)
	end
end

FastTravel.OnServerEvent:Connect(function(player: Player, checkpointName: string)
	local checkpoint = Checkpoints:FindFirstChild(checkpointName)
	local playerUnlocks = unlocked[player]
	if not checkpoint or not checkpoint:IsA("BasePart") or not playerUnlocks or not playerUnlocks[checkpointName] then
		return
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if root then
		root.CFrame = checkpoint.CFrame + Vector3.new(0, 4, 0)
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	unlocked[player] = { Spawn = true }
end)

Players.PlayerRemoving:Connect(function(player: Player)
	unlocked[player] = nil
end)
