--!strict
-- Food tools: when the player clicks with a food tool, the client fires
-- EatFood with the tool. The server heals by the food's value (a server
-- table lookup, fine) and destroys the tool. The only check on the tool is
-- that it is an Instance whose name is a known food.
--
-- Exploit: fire EatFood with ReplicatedStorage.Shop.Cake (the shop's display
-- template) or with the burger another player is holding (it lives in their
-- character in Workspace). The server destroys someone else's item, breaks the
-- shop for everyone, and heals the exploiter for free as often as they like.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EatFood = ReplicatedStorage.Remotes.EatFood :: RemoteEvent

local FOOD_HEAL: { [string]: number } = {
	Apple = 15,
	Burger = 40,
	Cake = 60,
}

EatFood.OnServerEvent:Connect(function(player: Player, tool: Tool)
	if typeof(tool) ~= "Instance" then
		return
	end
	local heal = FOOD_HEAL[tool.Name]
	if not heal then
		return
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	tool:Destroy() -- expect: luau-shield003
	humanoid.Health = math.min(humanoid.Health + heal, humanoid.MaxHealth)
end)
