--!strict
-- Medic abilities (handlers table connected in a loop), fixed: the heal
-- amount is checked against both bounds, the target must be a teammate, and
-- the resulting Health is clamped between 0 and MaxHealth (both server
-- values), so a negative or huge amount can no longer kill or overheal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MedicRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Medic")

local MAX_HEAL = 30
local BANDAGE_HEAL = 15

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local handlers: { [string]: (Player, ...any) -> () } = {}

function handlers.Heal(medic: Player, targetUserId: number, amount: number)
	if typeof(amount) ~= "number" or amount < 0 or amount > MAX_HEAL then
		return
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target.Team ~= medic.Team then
		return
	end

	local humanoid = getHumanoid(target)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid.Health = math.clamp(humanoid.Health + amount, 0, humanoid.MaxHealth)
end

function handlers.Bandage(medic: Player)
	local humanoid = getHumanoid(medic)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.Health + BANDAGE_HEAL, humanoid.MaxHealth)
	end
end

for name, handler in handlers do
	local remote = MedicRemotes:WaitForChild(name) :: RemoteEvent
	remote.OnServerEvent:Connect(handler)
end
