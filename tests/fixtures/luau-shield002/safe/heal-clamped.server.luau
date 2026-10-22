--!strict
-- Medic abilities (handlers table connected in a loop), fixed: the heal
-- amount is checked against both bounds, the target must be a teammate within
-- HEAL_RANGE studs, and the new Health is clamped between 0 and MaxHealth
-- (server values), so a negative or huge amount can neither kill nor overheal.
-- Both abilities share a cooldown: a bounded heal that can be fired every
-- frame is still god mode.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MedicRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Medic")

local MAX_HEAL = 30
local BANDAGE_HEAL = 15
local HEAL_RANGE = 15
local HEAL_COOLDOWN = 1
local lastHeal: { [Player]: number } = {}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function onCooldown(player: Player): boolean
	local now = os.clock()
	if now - (lastHeal[player] or 0) < HEAL_COOLDOWN then
		return true
	end
	lastHeal[player] = now
	return false
end

local handlers: { [string]: (Player, ...any) -> () } = {}

function handlers.Heal(medic: Player, targetUserId: number, amount: number)
	if typeof(amount) ~= "number" or amount < 0 or amount > MAX_HEAL or onCooldown(medic) then
		return
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	local humanoid = if target and target.Team == medic.Team then getHumanoid(target) else nil
	local medicHumanoid = getHumanoid(medic)
	local targetRoot = if humanoid then humanoid.RootPart else nil
	local medicRoot = if medicHumanoid then medicHumanoid.RootPart else nil
	if not humanoid or not targetRoot or not medicRoot or humanoid.Health <= 0 then
		return
	end
	if (targetRoot.Position - medicRoot.Position).Magnitude > HEAL_RANGE then
		return
	end

	humanoid.Health = math.clamp(humanoid.Health + amount, 0, humanoid.MaxHealth)
end

function handlers.Bandage(medic: Player)
	local humanoid = getHumanoid(medic)
	if humanoid and humanoid.Health > 0 and not onCooldown(medic) then
		humanoid.Health = math.min(humanoid.Health + BANDAGE_HEAL, humanoid.MaxHealth)
	end
end

for name, handler in handlers do
	local remote = MedicRemotes:WaitForChild(name) :: RemoteEvent
	remote.OnServerEvent:Connect(handler)
end

Players.PlayerRemoving:Connect(function(player: Player)
	lastHeal[player] = nil
end)
