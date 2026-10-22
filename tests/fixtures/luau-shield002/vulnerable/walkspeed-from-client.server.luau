--!strict
-- Sprint: while the sprint key is held, the client sends the WalkSpeed it
-- wants. The parameter is annotated `speed: number` (erased at runtime) and
-- checked with typeof, and the if-expression only gives a lower bound.
--
-- Exploit: fire SetSprintSpeed with 500. The server-side movement anti-cheat
-- compares the distance travelled with humanoid.WalkSpeed, so the exploiter
-- now runs at 500 studs/s with the server's blessing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SetSprintSpeed = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSprintSpeed") :: RemoteEvent

local DEFAULT_SPEED = 16

local function onSetSprintSpeed(player: Player, speed: number)
	if typeof(speed) ~= "number" then
		return
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = if speed > 0 then speed else DEFAULT_SPEED -- expect: luau-shield002
end

SetSprintSpeed.OnServerEvent:Connect(onSetSprintSpeed)
