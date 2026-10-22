--!strict
-- Treasure chests: the client fires OpenChest with the chest part it clicked.
-- The reward is read from the chest's "Reward" attribute, which only the
-- server sets, so the AMOUNT is not client-controlled. But the client chooses
-- WHICH chest: nothing checks that the player is anywhere near it. Reading
-- the reward from the chest and adding it to leaderstats is the first use of
-- the unverified Instance, so luau-shield003 is reported on that line.
--
-- Exploit: loop over every part with a "Reward" attribute (the legendary chest
-- behind the boss, the chests of the event map, the quest NPC holding a
-- 5000-coin reward) and fire OpenChest for each one, from spawn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OpenChest = ReplicatedStorage.Remotes.OpenChest :: RemoteEvent

local function onOpenChest(player: Player, chest: BasePart)
	if typeof(chest) ~= "Instance" or not chest:IsA("BasePart") then
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

	coins.Value += reward -- expect: luau-shield003
	chest:SetAttribute("Opened", true)
	chest.Transparency = 0.5
	print(`{player.Name} opened {chest:GetFullName()} for {reward} coins`)
end

OpenChest.OnServerEvent:Connect(onOpenChest)
