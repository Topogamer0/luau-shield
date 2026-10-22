--!strict
-- Melee combat: the sword's LocalScript does the hit detection (it feels more
-- responsive on the client) and fires SwordHit with the part it touched. The
-- server checks the swing cooldown, that the attacker holds a sword and that
-- the victim is not the attacker, then damages the Humanoid of the model the
-- part belongs to. It never checks that the part is anywhere near the
-- attacker. The Humanoid is reached THROUGH the client's part, so damaging it
-- is the first use of the unverified Instance. (The damage itself is a server
-- constant: no luau-shield002.)
--
-- Exploit (kill aura): every 0.4 s, fire SwordHit with the HumanoidRootPart
-- of every other player. Everyone on the server dies, wherever they are.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwordHit = ReplicatedStorage.Remotes.SwordHit :: RemoteEvent

local DAMAGE = 20
local SWING_COOLDOWN = 0.4
local lastSwing: { [Player]: number } = {}

SwordHit.OnServerEvent:Connect(function(player: Player, hitPart: BasePart)
	local now = os.clock()
	if now - (lastSwing[player] or 0) < SWING_COOLDOWN then
		return
	end
	lastSwing[player] = now

	local character = player.Character
	if not character or not character:FindFirstChild("Sword") then
		return
	end
	if typeof(hitPart) ~= "Instance" or not hitPart:IsA("BasePart") then
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

	humanoid:TakeDamage(DAMAGE) -- expect: luau-shield003
end)
