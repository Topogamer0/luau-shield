--!strict
-- Building game, fixed: the client only sends the block. The server finds
-- the player's plot itself (plots are named after the owner's UserId) and
-- checks plot:IsAncestorOf(block), so blocks of other plots, the lobby and
-- the spawn are rejected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeleteBlock = ReplicatedStorage.Remotes.DeleteBlock :: RemoteEvent
local Plots = workspace:WaitForChild("Plots")

DeleteBlock.OnServerEvent:Connect(function(player: Player, block: BasePart)
	local plot = Plots:FindFirstChild(tostring(player.UserId))
	if not plot or typeof(block) ~= "Instance" or not plot:IsAncestorOf(block) then
		return
	end
	if not block:IsA("BasePart") or block:GetAttribute("Locked") then
		return
	end

	block:Destroy()
end)
