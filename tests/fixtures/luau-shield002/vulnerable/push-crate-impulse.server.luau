--!strict
-- Physics puzzle: players push server-owned crates. The client computes the
-- push from the camera direction and sends the impulse to apply. The server
-- checks that the player stands next to the crate, but the distance check is
-- about the crate, not about the impulse.
--
-- Exploit: send Vector3.new(0, 1e7, 0): the crate is launched across the map
-- and flings every player it touches on the way down.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PushCrate = ReplicatedStorage.Remotes.PushCrate :: RemoteEvent
local Crates = workspace:WaitForChild("Crates")

local MAX_PUSH_DISTANCE = 8

PushCrate.OnServerEvent:Connect(function(player: Player, crateName: string, impulse: Vector3)
	local crate = Crates:FindFirstChild(crateName)
	if not crate or not crate:IsA("BasePart") or typeof(impulse) ~= "Vector3" then
		return
	end

	if player:DistanceFromCharacter(crate.Position) > MAX_PUSH_DISTANCE then
		return
	end

	crate:ApplyImpulse(impulse) -- expect: luau-shield002
end)
