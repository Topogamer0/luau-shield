--!strict
-- Sprint with a clamped speed: the client still sends the speed it wants
-- (analog stick pressure), but math.clamp gives it a lower and an upper
-- bound before it reaches WalkSpeed. luau-shield002 does not require NaN rejection
-- (unlike currency writes, see luau-shield001).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SetSprintSpeed = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSprintSpeed") :: RemoteEvent

local WALK_SPEED = 16
local MAX_SPRINT_SPEED = 24

local function onSetSprintSpeed(player: Player, speed: number)
	if typeof(speed) ~= "number" then
		return
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = math.clamp(speed, WALK_SPEED, MAX_SPRINT_SPEED)
end

SetSprintSpeed.OnServerEvent:Connect(onSetSprintSpeed)
