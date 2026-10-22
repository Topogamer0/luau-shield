-- Lobby features: fireworks, the bug report board and the analytics events
-- sent by the client UI.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Modules.Analytics)
local Remotes = require(script.Parent.Modules.Remotes)

local effects = ServerStorage:WaitForChild("Effects")

-- Launches a firework rocket above the player.
Remotes.LaunchFirework.OnServerEvent:Connect(function(player: Player, effectName: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local effect = effects:FindFirstChild(effectName)
	if not root or not effect then
		return
	end
	local rocket = Instance.new("Part")
	rocket.Name = "Firework"
	rocket.Size = Vector3.new(0.6, 2, 0.6)
	rocket.CFrame = root.CFrame + Vector3.new(0, 4, 0)
	rocket.CanCollide = false
	rocket.AssemblyLinearVelocity = Vector3.new(0, 60, 0)
	effect:Clone().Parent = rocket
	rocket.Parent = workspace
	Debris:AddItem(rocket, Config.FireworkLifetime)
end)

Remotes.SubmitBugReport.OnServerEvent:Connect(function(player: Player, category: string, text: string)
	Analytics.reportBug(player, category, text)
end)

Remotes.TrackEvent.OnServerEvent:Connect(function(player: Player, eventName: string, properties: { [string]: any })
	Analytics.track(player, eventName, properties)
end)
