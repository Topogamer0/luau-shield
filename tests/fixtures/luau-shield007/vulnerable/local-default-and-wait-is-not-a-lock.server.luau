-- Vulnerable (v0.2.0 review): `if not color then color = ... end` on a local, then a wait, is not a lock.
-- No rate limit: every request clones a firework. A handler-local default
-- (`if not color then color = ... end`) and a task.wait for the fuse are
-- taken as a "global lock held while waiting".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Launch = ReplicatedStorage.Remotes.LaunchFirework
local Firework = ServerStorage.Effects.Firework
local favourite: { [Player]: Color3 } = {}

Launch.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local color = favourite[player]
	if not color then
		color = Color3.new(1, 1, 1)
	end
	local fw = Firework:Clone()
	fw.Color = color
	fw.Parent = workspace
	task.wait(2) -- fuse
	fw:Destroy()
end)
