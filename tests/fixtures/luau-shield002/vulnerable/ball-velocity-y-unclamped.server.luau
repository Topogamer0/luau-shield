--!strict
-- Soccer: the client aims a kick and sends the velocity for the ball, whose
-- network owner is the server. X and Z are clamped component by component,
-- but the vertical component was forgotten, so the Vector3 is not bounded.
--
-- Exploit: kick with velocity.Y = 1e6. The ball leaves the map and the match
-- can never end, or it comes back down fast enough to fling players.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kick = ReplicatedStorage.Remotes.Kick :: RemoteEvent
local ball = workspace:WaitForChild("Ball") :: BasePart

local MAX_KICK_SPEED = 120
local KICK_RANGE = 6

ball:SetNetworkOwner(nil)

Kick.OnServerEvent:Connect(function(player: Player, velocity: Vector3)
	if typeof(velocity) ~= "Vector3" then
		return
	end
	if player:DistanceFromCharacter(ball.Position) > KICK_RANGE then
		return
	end

	local x = math.clamp(velocity.X, -MAX_KICK_SPEED, MAX_KICK_SPEED)
	local z = math.clamp(velocity.Z, -MAX_KICK_SPEED, MAX_KICK_SPEED)
	ball.AssemblyLinearVelocity = Vector3.new(x, velocity.Y, z) -- expect: luau-shield002
end)
