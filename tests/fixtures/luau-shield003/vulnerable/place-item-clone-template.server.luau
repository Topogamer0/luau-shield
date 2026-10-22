--!strict
-- Furniture placement: the build menu fires PlaceItem with the template Model
-- the player picked, and the server clones it into the player's plot. The
-- only check is that the model is marked "Placeable". The game-pass items in
-- ReplicatedStorage.VIPItems are Placeable too (the menu greys them out, on
-- the client), and so is every piece of furniture already placed in a plot.
-- :Clone() on the client's Instance is the first use. Cloning without any
-- rate limit is also a luau-shield007.
--
-- Exploit: fire PlaceItem with ReplicatedStorage.VIPItems.GoldenThrone (free
-- game-pass items), or with the models of another player's house to copy it
-- piece by piece. Firing it in a loop fills the server with clones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceItem = ReplicatedStorage.Remotes.PlaceItem :: RemoteEvent
local Plots = workspace:WaitForChild("Plots")

PlaceItem.OnServerEvent:Connect(function(player: Player, template: Model) -- expect: luau-shield007
	if typeof(template) ~= "Instance" or not template:IsA("Model") then
		return
	end
	if template:GetAttribute("Placeable") ~= true then
		return
	end
	local plot = Plots:FindFirstChild(player.Name)
	if not plot then
		return
	end

	local copy = template:Clone() -- expect: luau-shield003
	copy:PivotTo(plot:GetPivot())
	copy.Parent = plot
end)
