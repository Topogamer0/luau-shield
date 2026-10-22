--!strict
-- Soccer, fixed: instead of clamping components one by one, the handler
-- rejects any kick whose speed (the magnitude of the velocity) is above
-- MAX_KICK_SPEED. The check must pass for execution to continue, so the
-- whole Vector3 is bounded when it reaches AssemblyLinearVelocity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kick = ReplicatedStorage.Remotes.Kick :: RemoteEvent
local ball = workspace:WaitForChild("Ball") :: BasePart

local MAX_KICK_SPEED = 120
local KICK_RANGE = 6

ball:SetNetworkOwner(nil)

Kick.OnServerEvent:Connect(function(player: Player, velocity: Vector3)
	if typeof(velocity) ~= "Vector3" or velocity.Magnitude > MAX_KICK_SPEED then
		return
	end
	if player:DistanceFromCharacter(ball.Position) > KICK_RANGE then
		return
	end

	ball.AssemblyLinearVelocity = velocity
end)
