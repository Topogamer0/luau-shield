--!strict
-- Medic class abilities. Each ability is a RemoteEvent named after its
-- handler in the `handlers` table, and the handlers are connected in a loop.
-- Heal caps the new Health at MaxHealth with math.min: that is only an upper
-- bound, the amount can still be negative.
--
-- Exploit: "heal" an enemy (the target is any player, looked up by UserId)
-- with amount = -1e6: their Health drops below zero and they die instantly,
-- from anywhere on the map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MedicRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Medic")

local BANDAGE_HEAL = 15

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local handlers: { [string]: (Player, ...any) -> () } = {}

function handlers.Heal(medic: Player, targetUserId: number, amount: number)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		return
	end

	local humanoid = getHumanoid(target)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth) -- expect: luau-shield002
end

-- No luau-shield002 finding here: the amount is a server constant.
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
