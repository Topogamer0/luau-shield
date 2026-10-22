--!strict
-- Melee hits on breakable crates are sent on an UnreliableRemoteEvent (they
-- are frequent and losing one does not matter). The server checks that the
-- part is marked "Breakable" and schedules it for removal with Debris. An
-- attribute that says what a part IS does not say where it is.
--
-- Exploit: the glass walls of every team base and the vault door are also
-- "Breakable" (they are meant to be broken from up close). Fire HitCrate with
-- each of them from spawn: every base on the map is opened at once.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitCrate = ReplicatedStorage.Remotes.HitCrate :: UnreliableRemoteEvent

local BREAK_DELAY = 0.25

HitCrate.OnServerEvent:Connect(function(player: Player, crate: BasePart)
	if typeof(crate) ~= "Instance" or not crate:IsA("BasePart") then
		return
	end
	if crate:GetAttribute("Breakable") ~= true or crate:GetAttribute("Broken") then
		return
	end

	Debris:AddItem(crate, BREAK_DELAY) -- expect: luau-shield003
	crate:SetAttribute("Broken", true)
	crate.Anchored = false
end)
