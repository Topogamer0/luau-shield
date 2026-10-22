--!strict
-- Blink ability, fixed: the range check returns instead of only warning, so
-- the destination is within BLINK_RANGE studs of the character whenever
-- MoveTo runs.

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
		return
	end

	character:MoveTo(destination)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastBlink[player] = nil
end)
