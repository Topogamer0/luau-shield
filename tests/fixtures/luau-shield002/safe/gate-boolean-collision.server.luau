--!strict
-- Base owners can open and close the gate of their own base. The client sends
-- the desired state; once it is known to be a boolean it has only two
-- possible values, so assigning it to CanCollide is safe. The gate itself is
-- found on the server from the player's name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SetGateClosed = ReplicatedStorage.Remotes.SetGateClosed :: RemoteEvent

SetGateClosed.OnServerEvent:Connect(function(player: Player, closed: boolean)
	if typeof(closed) ~= "boolean" then
		return
	end

	local base = workspace.Bases:FindFirstChild(player.Name)
	local gate = if base then base:FindFirstChild("Gate") else nil
	if not gate or not gate:IsA("BasePart") then
		return
	end

	gate.CanCollide = closed
	gate.Transparency = if closed then 0 else 0.6
end)
