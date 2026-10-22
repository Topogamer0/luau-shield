--!strict
-- Food tools, fixed: the tool must be inside the player's own character
-- (that is where an equipped tool lives) before it is destroyed. Shop
-- templates and other players' food fail the IsDescendantOf check.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EatFood = ReplicatedStorage.Remotes.EatFood :: RemoteEvent

local FOOD_HEAL: { [string]: number } = {
	Apple = 15,
	Burger = 40,
	Cake = 60,
}

EatFood.OnServerEvent:Connect(function(player: Player, tool: Tool)
	local character = player.Character
	if not character or typeof(tool) ~= "Instance" or not tool:IsDescendantOf(character) then
		return
	end
	local heal = FOOD_HEAL[tool.Name]
	if not heal then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	tool:Destroy()
	humanoid.Health = math.min(humanoid.Health + heal, humanoid.MaxHealth)
end)
