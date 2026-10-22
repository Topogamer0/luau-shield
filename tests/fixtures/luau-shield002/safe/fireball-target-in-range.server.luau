--!strict
-- Fireball, done right: the client fires CastFireball with the point under
-- its mouse (a RemoteEvent, so the server never waits on a client). The target
-- must be within RANGE studs of the caster's HumanoidRootPart, a distance
-- check that must pass for execution to continue, and casts have a cooldown
-- measured with os.clock because each one creates an Explosion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CastFireball = ReplicatedStorage.Remotes.CastFireball :: RemoteEvent

local RANGE = 60
local COOLDOWN = 2
local lastCast: { [Player]: number } = {}

CastFireball.OnServerEvent:Connect(function(player: Player, target: Vector3)
	local now = os.clock()
	if now - (lastCast[player] or 0) < COOLDOWN then
		return
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or typeof(target) ~= "Vector3" or (target - root.Position).Magnitude > RANGE then
		return
	end
	lastCast[player] = now

	local explosion = Instance.new("Explosion")
	explosion.BlastRadius = 8
	explosion.Position = target
	explosion.Parent = workspace
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastCast[player] = nil
end)
