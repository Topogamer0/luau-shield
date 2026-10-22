--!strict
-- Sprint toggle: the client says whether the sprint key is held and the
-- server picks one of its own two speeds. Looks like a client value flowing
-- into WalkSpeed, but the client value is only the condition of the
-- if-expression: the value written is always WALK_SPEED or SPRINT_SPEED, so
-- even a non-boolean argument cannot choose the speed.
-- (The older `sprinting and SPRINT_SPEED or WALK_SPEED` idiom is reported:
-- see the Limitations of docs/rules/luau-shield002.md.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SetSprinting = ReplicatedStorage.Remotes.SetSprinting :: RemoteEvent

local WALK_SPEED = 16
local SPRINT_SPEED = 24

SetSprinting.OnServerEvent:Connect(function(player: Player, sprinting: boolean)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = if sprinting then SPRINT_SPEED else WALK_SPEED
	end
end)
