--!strict
-- Mining: clicking an ore with the pickaxe fires MineOre with the ore and the
-- mouse hit position. The server "verifies the click" by checking that the
-- hit position is close to the ore. But BOTH values come from the client: the
-- check only proves that the two arguments agree with each other, not that
-- the ore is anywhere near the player. Like the container of IsDescendantOf,
-- the reference point of a distance check must be a server value (the
-- character's HumanoidRootPart).
--
-- Exploit: on the client, loop over CollectionService:GetTagged("Ore") and
-- fire MineOre(ore, ore.Position) for each one, four times a second. The
-- rare ores at the bottom of the mine are farmed from spawn, without digging.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MineOre = ReplicatedStorage.Remotes.MineOre :: RemoteEvent

local CLICK_TOLERANCE = 4
local HIT_COOLDOWN = 0.25
local lastHit: { [Player]: number } = {}

MineOre.OnServerEvent:Connect(function(player: Player, ore: BasePart, hitPosition: Vector3)
	local now = os.clock()
	if now - (lastHit[player] or 0) < HIT_COOLDOWN then
		return
	end
	lastHit[player] = now

	if typeof(ore) ~= "Instance" or not ore:IsA("BasePart") or not ore:HasTag("Ore") then
		return
	end
	if typeof(hitPosition) ~= "Vector3" or (ore.Position - hitPosition).Magnitude > CLICK_TOLERANCE then
		return
	end

	local hits = ore:GetAttribute("Hits")
	local newHits = (if typeof(hits) == "number" then hits else 0) + 1
	ore:SetAttribute("Hits", newHits) -- expect: luau-shield003
	if newHits >= 5 then
		ore:Destroy()
	end
end)
