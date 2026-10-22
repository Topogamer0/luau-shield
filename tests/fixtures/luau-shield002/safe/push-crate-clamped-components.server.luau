--!strict
-- Physics puzzle, fixed: every component of the impulse is clamped with
-- math.clamp (and the vertical one is dropped), so the crate can only be
-- pushed horizontally and never harder than MAX_IMPULSE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PushCrate = ReplicatedStorage.Remotes.PushCrate :: RemoteEvent
local Crates = workspace:WaitForChild("Crates")

local MAX_PUSH_DISTANCE = 8
local MAX_IMPULSE = 600

PushCrate.OnServerEvent:Connect(function(player: Player, crateName: string, impulse: Vector3)
	local crate = Crates:FindFirstChild(crateName)
	if not crate or not crate:IsA("BasePart") or typeof(impulse) ~= "Vector3" then
		return
	end

	if player:DistanceFromCharacter(crate.Position) > MAX_PUSH_DISTANCE then
		return
	end

	local clamped = Vector3.new(
		math.clamp(impulse.X, -MAX_IMPULSE, MAX_IMPULSE),
		0,
		math.clamp(impulse.Z, -MAX_IMPULSE, MAX_IMPULSE)
	)
	crate:ApplyImpulse(clamped)
end)
