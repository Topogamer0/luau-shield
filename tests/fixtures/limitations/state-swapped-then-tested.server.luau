-- Known limitation (false positive): the state is written first and its previous value tested after; only test-then-change is recognised.
-- Well-written "ready" state: the previous value is read, the new one
-- written, and the request stops when the player was already ready. A second
-- request reads "Ready" and returns: the beam is cloned once per
-- not-ready -> ready transition.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ReadyUp = ReplicatedStorage.Remotes.ReadyUp
local ReadyBeam = ServerStorage.Effects.ReadyBeam
local state: { [Player]: string } = {}

ReadyUp.OnServerEvent:Connect(function(player: Player)
	local previous = state[player]
	state[player] = "Ready"
	if previous == "Ready" then
		return
	end
	local character = player.Character
	if character then
		ReadyBeam:Clone().Parent = character
	end
end)
