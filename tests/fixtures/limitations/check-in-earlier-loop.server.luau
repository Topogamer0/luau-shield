-- Limitation: checks made on each element in one loop do not carry over to a
-- second loop over the same table. The first loop refuses the whole request
-- unless every part is on the player's plot, so the second loop only destroys
-- verified parts. luau-shield only knows facts about the loop variable of the
-- loop it is in and reports the `Destroy` (false positive).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage.Remotes.DeleteSelection.OnServerEvent:Connect(function(player: Player, parts: { BasePart })
	local plot = workspace.Plots:FindFirstChild(player.Name)
	if not plot or typeof(parts) ~= "table" or #parts > 50 then
		return
	end
	for _, part in parts do
		if typeof(part) ~= "Instance" or not part:IsDescendantOf(plot) then
			return
		end
	end
	for _, part in parts do
		part:Destroy()
	end
end)
