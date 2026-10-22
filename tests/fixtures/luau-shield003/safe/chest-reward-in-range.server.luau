--!strict
-- Treasure chests, fixed: the player must be standing next to the chest.
-- player:DistanceFromCharacter(chest.Position) is a location check on the
-- chest, so reading its reward and marking it opened is fine. (The reward
-- itself comes from a server-set attribute, so it is not client data.)
-- DistanceFromCharacter measures from the character's Head and returns 0
-- when there is no Head, so the handler requires one: a headless character
-- would otherwise pass any range check.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OpenChest = ReplicatedStorage.Remotes.OpenChest :: RemoteEvent

local OPEN_RANGE = 12

local function onOpenChest(player: Player, chest: BasePart)
	if typeof(chest) ~= "Instance" or not chest:IsA("BasePart") then
		return
	end
	local character = player.Character
	if not character or not character:FindFirstChild("Head") then
		return
	end
	if player:DistanceFromCharacter(chest.Position) > OPEN_RANGE then
		return
	end
	if chest:GetAttribute("Opened") then
		return
	end

	local reward = chest:GetAttribute("Reward")
	if typeof(reward) ~= "number" then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = if leaderstats then leaderstats:FindFirstChild("Coins") :: IntValue? else nil
	if not coins then
		return
	end

	coins.Value += reward
	chest:SetAttribute("Opened", true)
	chest.Transparency = 0.5
	print(`{player.Name} opened {chest:GetFullName()} for {reward} coins`)
end

OpenChest.OnServerEvent:Connect(onOpenChest)
