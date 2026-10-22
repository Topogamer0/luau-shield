--!strict
-- Melee combat: hits are detected on the client (hitbox raycasts) and
-- reported with the victim's UserId and the damage the client computed.
-- The victim is looked up on the server, but the damage is the client's.
--
-- Exploit: report damage = 1e9 against every player in the server and kill
-- them all in one frame. t.number gives a type and "damage <= 0" a lower
-- bound; nothing gives an upper bound.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local t = require(ReplicatedStorage.Packages.t)

local MeleeHit = ReplicatedStorage.Remotes.MeleeHit :: RemoteEvent

MeleeHit.OnServerEvent:Connect(function(attacker: Player, victimUserId: number, damage: number)
	if not t.number(damage) or damage <= 0 then
		return
	end

	local victim = Players:GetPlayerByUserId(victimUserId)
	if not victim or victim == attacker or not victim.Character then
		return
	end

	local humanoid = victim.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(damage) -- expect: luau-shield002
	end
end)
