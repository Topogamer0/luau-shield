--!strict
-- Vulnerable: footstep dust is requested through an UnreliableRemoteEvent and
-- the server clones an emitter for each request. Unreliable remotes are made
-- to be fired every frame: an exploiter fires this one thousands of times
-- per second and floods the server, and every client, with emitters.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Footstep = ReplicatedStorage.Remotes.Footstep :: UnreliableRemoteEvent
local dustTemplate = ServerStorage.Effects.FootstepDust

Footstep.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local dust = dustTemplate:Clone()
	dust.Parent = root
	Debris:AddItem(dust, 0.5)
end)
