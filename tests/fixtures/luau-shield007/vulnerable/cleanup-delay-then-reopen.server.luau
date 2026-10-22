-- Vulnerable (v0.2.0 review): a cleanup is scheduled with `task.delay`, then the state is reopened at once.
-- Fixture global-state-reopened-at-once with the two last statements
-- swapped: the cleanup task.delay is scheduled BEFORE the state is put back.
-- The handler never yields: no other request ever sees the state closed, and
-- every request clones the confetti. task.delay does not wait; it only
-- schedules the cleanup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Remote = ReplicatedStorage.Remotes.Confetti
local fxState = "Idle"

Remote.OnServerEvent:Connect(function(player) -- expect: luau-shield007
	if fxState ~= "Idle" then
		return
	end
	fxState = "Playing"
	local fx = ServerStorage.Confetti:Clone()
	fx.Parent = workspace
	task.delay(3, function()
		fx:Destroy()
	end)
	fxState = "Idle"
end)
