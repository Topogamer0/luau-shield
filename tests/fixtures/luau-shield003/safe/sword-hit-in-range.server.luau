--!strict
-- Melee combat, fixed: the hit part must be within the sword's reach of the
-- attacker's HumanoidRootPart before anything is done with it. The check
-- comes first, so the Humanoid found through the part is checked too. A kill
-- aura can now only hit players who are actually next to the exploiter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwordHit = ReplicatedStorage.Remotes.SwordHit :: RemoteEvent

local DAMAGE = 20
local SWORD_REACH = 8
local SWING_COOLDOWN = 0.4
local lastSwing: { [Player]: number } = {}

SwordHit.OnServerEvent:Connect(function(player: Player, hitPart: BasePart)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < SWING_COOLDOWN then
		return
	end
	lastSwing[player] = now

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not character or not root or not character:FindFirstChild("Sword") then
		return
	end
	if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then
		return
	end
	if (hitPart.Position - root.Position).Magnitude > SWORD_REACH then
		return
	end

	local victim = hitPart.Parent
	if not victim or victim == character then
		return
	end
	local humanoid = victim:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid:TakeDamage(DAMAGE)
end)
