--!strict
-- Mining, fixed: the server ignores where the client says it clicked and
-- checks the distance between the ore and the player's own
-- HumanoidRootPart, a server reference point. Ores on the other side of the
-- mine are out of reach.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MineOre = ReplicatedStorage.Remotes.MineOre :: RemoteEvent

local PICKAXE_REACH = 10
local HIT_COOLDOWN = 0.25
local lastHit: { [Player]: number } = {}

MineOre.OnServerEvent:Connect(function(player: Player, ore: BasePart)
	local now = os.clock()
	if now - (lastHit[player] or 0) < HIT_COOLDOWN then
		return
	end
	lastHit[player] = now

	if typeof(ore) ~= "Instance" or not ore:IsA("BasePart") or not ore:HasTag("Ore") then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or (ore.Position - root.Position).Magnitude > PICKAXE_REACH then
		return
	end

	local hits = ore:GetAttribute("Hits")
	local newHits = (if typeof(hits) == "number" then hits else 0) + 1
	ore:SetAttribute("Hits", newHits)
	if newHits >= 5 then
		ore:Destroy()
	end
end)
