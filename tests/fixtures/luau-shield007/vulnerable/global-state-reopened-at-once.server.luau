-- Vulnerable (v0.2.0 review): a global state reopened right after the work never stops a request.
-- String-state twin of debounce-cleanup-delay.
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
	fxState = "Idle"
	task.delay(3, function()
		fx:Destroy()
	end)
end)
