--!strict
-- Building game: the delete tool fires DeleteBlock with the player's plot and
-- the block to delete, and the server checks that the block is inside that
-- plot. But the plot comes from the client too: IsDescendantOf a container
-- the client chose proves nothing. Only the block is used (the plot is only
-- passed to a read-only query), so there is one finding, for `block`.
--
-- Exploit: fire DeleteBlock(otherPlot, block) for every block of every other
-- plot, or simply DeleteBlock(workspace, anything): every build on the
-- server, the lobby and the spawn are deleted in a few seconds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeleteBlock = ReplicatedStorage.Remotes.DeleteBlock :: RemoteEvent

DeleteBlock.OnServerEvent:Connect(function(player: Player, plot: Model, block: BasePart)
	if typeof(plot) ~= "Instance" or typeof(block) ~= "Instance" then
		return
	end
	if not block:IsA("BasePart") or not block:IsDescendantOf(plot) then
		return
	end
	if block:GetAttribute("Locked") then
		return
	end

	block:Destroy() -- expect: luau-shield003
end)
