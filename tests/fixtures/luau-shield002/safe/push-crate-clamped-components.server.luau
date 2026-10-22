--!strict
-- Physics puzzle, fixed: every component of the impulse is clamped with
-- math.clamp (and the vertical one is dropped), so one push is horizontal and
-- never harder than MAX_IMPULSE. Impulses add up, so each crate also has a
-- cooldown: without it, firing the remote every frame would still build an
-- unbounded velocity out of bounded pushes. The range is measured from the
-- HumanoidRootPart, because DistanceFromCharacter returns 0 when the player
-- has no character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PushCrate = ReplicatedStorage.Remotes.PushCrate :: RemoteEvent
local Crates = workspace:WaitForChild("Crates")

local MAX_PUSH_DISTANCE = 8
local MAX_IMPULSE = 600
local PUSH_COOLDOWN = 0.5
local lastPush: { [Instance]: number } = {}

PushCrate.OnServerEvent:Connect(function(player: Player, crateName: string, impulse: Vector3)
	local crate = Crates:FindFirstChild(crateName)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not crate or not crate:IsA("BasePart") or not root or typeof(impulse) ~= "Vector3" then
		return
	end

	local now = os.clock()
	if (crate.Position - root.Position).Magnitude > MAX_PUSH_DISTANCE or now - (lastPush[crate] or 0) < PUSH_COOLDOWN then
		return
	end
	lastPush[crate] = now

	local clamped = Vector3.new(
		math.clamp(impulse.X, -MAX_IMPULSE, MAX_IMPULSE),
		0,
		math.clamp(impulse.Z, -MAX_IMPULSE, MAX_IMPULSE)
	)
	crate:ApplyImpulse(clamped)
end)
