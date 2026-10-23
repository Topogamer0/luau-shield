-- Vulnerable (v0.2.0 review): the per-player version: the state is reopened at once, not by the delayed cleanup.
-- Per-player version: the state is closed, the effect cloned, a cleanup
-- scheduled with task.delay, and the state reopened right away, with no
-- yield in between. Every request clones an effect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Emote = ReplicatedStorage.Remotes.Emote
local Sparkles = ServerStorage.Effects.Sparkles
local state: { [Player]: string } = {}

Emote.OnServerEvent:Connect(function(player: Player) -- expect: luau-shield007
	local character = player.Character
	if not character or state[player] ~= "Idle" then
		return
	end
	state[player] = "Emoting"
	local fx = Sparkles:Clone()
	fx.Parent = character
	task.delay(2, function()
		fx:Destroy()
	end)
	state[player] = "Idle"
end)
