-- Vulnerable (v0.2.0 review): a handler connected inside another one does not inherit its state checks.
-- The outer handler only tests the state (no transition). The nested Ready
-- handler writes the state without testing it, then clones on every request.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Remotes = ReplicatedStorage.Remotes
local state = {}

Remotes.JoinRound.OnServerEvent:Connect(function(player)
	if state[player] ~= "Lobby" then
		return
	end
	Remotes.Ready.OnServerEvent:Connect(function(p) -- expect: luau-shield007
		if p ~= player then
			return
		end
		state[player] = "Ready"
		local beam = ServerStorage.Effects.ReadyBeam:Clone()
		beam.Parent = player.Character
	end)
end)
