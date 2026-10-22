--!strict
-- Soccer, fixed: instead of clamping components one by one, the handler
-- rejects any kick whose speed (the magnitude of the velocity) is above
-- MAX_KICK_SPEED. The check must pass for execution to continue, so the
-- whole Vector3 is bounded when it reaches AssemblyLinearVelocity. The range
-- is measured from the HumanoidRootPart: DistanceFromCharacter returns 0 when
-- the player has no character, so it would let a player in the menu kick.

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

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or (ball.Position - root.Position).Magnitude > KICK_RANGE then
		return
	end

	ball.AssemblyLinearVelocity = velocity
end)
