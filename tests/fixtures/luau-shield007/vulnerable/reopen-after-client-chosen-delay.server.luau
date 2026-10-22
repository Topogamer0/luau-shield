-- Vulnerable (v0.2.0 review): the state is reopened after a delay the client chooses (it can be zero).
-- Charged attack: the client says how long it charged (clamped to 0..3 s).
-- The state is closed before the effect is cloned and reopened after
-- `chargeTime` seconds, a value the client chooses: with chargeTime = 0 the
-- state reopens on the next frame, like task.delay(0) (which is reported),
-- so the client clones ~60 effects per second.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ChargedAttack = ReplicatedStorage.Remotes.ChargedAttack
local Blast = ServerStorage.Effects.Blast
local state: { [Player]: string } = {}

ChargedAttack.OnServerEvent:Connect(function(player: Player, chargeTime: unknown) -- expect: luau-shield007
	if typeof(chargeTime) ~= "number" or chargeTime ~= chargeTime then
		return
	end
	chargeTime = math.clamp(chargeTime, 0, 3)
	if state[player] ~= "Idle" then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	state[player] = "Attacking"
	local blast = Blast:Clone()
	blast.Parent = character
	task.delay(chargeTime, function()
		state[player] = "Idle"
		blast:Destroy()
	end)
end)
