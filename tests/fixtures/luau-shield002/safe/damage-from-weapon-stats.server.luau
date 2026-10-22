--!strict
-- Melee combat done right: the client only reports WHO it hit. The damage,
-- range and cooldown come from the server's weapon table, keyed by the tool
-- the attacker actually has equipped. No client number reaches TakeDamage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type Weapon = {
	damage: number,
	range: number,
	cooldown: number,
}

local WEAPONS: { [string]: Weapon } = {
	Sword = { damage = 25, range = 8, cooldown = 0.6 },
	Dagger = { damage = 12, range = 5, cooldown = 0.3 },
}

local MeleeHit = ReplicatedStorage.Remotes.MeleeHit :: RemoteEvent
local lastSwing: { [Player]: number } = {}

MeleeHit.OnServerEvent:Connect(function(attacker: Player, victimUserId: number)
	local character = attacker.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	local weapon = if tool then WEAPONS[tool.Name] else nil
	if not weapon then
		return
	end

	local now = os.clock()
	if now - (lastSwing[attacker] or 0) < weapon.cooldown then
		return
	end
	lastSwing[attacker] = now

	local victim = Players:GetPlayerByUserId(victimUserId)
	local victimCharacter = if victim and victim ~= attacker then victim.Character else nil
	local victimRoot = if victimCharacter then victimCharacter:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local humanoid = if victimCharacter then victimCharacter:FindFirstChildOfClass("Humanoid") else nil
	if not victimRoot or not humanoid then
		return
	end

	if attacker:DistanceFromCharacter(victimRoot.Position) > weapon.range then
		return
	end

	humanoid:TakeDamage(weapon.damage)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastSwing[player] = nil
end)
