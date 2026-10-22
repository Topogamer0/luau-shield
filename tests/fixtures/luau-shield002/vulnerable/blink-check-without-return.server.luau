--!strict
-- Blink ability: the client picks the destination under the mouse and the
-- server moves the character. The range check only logs a warning: it does
-- not stop execution, so it protects nothing.
--
-- Exploit: blink anywhere on the map (into the boss room, onto the finish
-- pad). The warning in the server log is the only trace.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blink = ReplicatedStorage.Remotes.Blink :: RemoteEvent

local BLINK_RANGE = 40
local BLINK_COOLDOWN = 3
local lastBlink: { [Player]: number } = {}

Blink.OnServerEvent:Connect(function(player: Player, destination: Vector3)
	local now = os.clock()
	if now - (lastBlink[player] or 0) < BLINK_COOLDOWN then
		return
	end
	lastBlink[player] = now

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not character or not root or typeof(destination) ~= "Vector3" then
		return
	end

	if (destination - root.Position).Magnitude > BLINK_RANGE then
		warn(`{player.Name} tried to blink too far`)
	end

	character:MoveTo(destination) -- expect: luau-shield002
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastBlink[player] = nil
end)
