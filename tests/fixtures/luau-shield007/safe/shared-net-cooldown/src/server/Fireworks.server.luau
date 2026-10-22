--!strict
-- Safe: every request goes through Net.canFire from the shared module, which
-- keeps a per-player os.clock() cooldown. The rate limit lives in the
-- required module, not in the handler itself.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Firework = ReplicatedStorage.Remotes.Firework :: RemoteEvent
local fireworkTemplate = ServerStorage.Effects.Firework

Firework.OnServerEvent:Connect(function(player: Player)
	if not Net.canFire(player, "Firework", 2) then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local firework = fireworkTemplate:Clone()
	firework:PivotTo(root.CFrame * CFrame.new(0, 12, 0))
	firework.Parent = workspace
	Debris:AddItem(firework, 4)
end)
