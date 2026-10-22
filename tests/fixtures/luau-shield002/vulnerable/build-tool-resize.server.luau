--!strict
-- Building game: the resize handles of the build tool send the new size of
-- one of the player's own parts. The part is looked up on the server inside
-- the player's plot, but the size is only checked against a minimum of
-- MIN_SIZE studs per axis: a lower bound with no upper bound.
--
-- Exploit: resize a part to 2048 x 2048 x 2048 (the engine maximum). The
-- anchored part swallows the map, traps every player inside it and covers
-- every other base.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResizePart = ReplicatedStorage.Remotes.Build.ResizePart :: RemoteEvent

local MIN_SIZE = 1

ResizePart.OnServerEvent:Connect(function(player: Player, partId: string, size: Vector3)
	local plot = workspace.Plots:FindFirstChild(player.Name)
	local build = if plot then plot:FindFirstChild("Build") else nil
	local part = if build then build:FindFirstChild(partId) else nil
	if not part or not part:IsA("BasePart") or typeof(size) ~= "Vector3" then
		return
	end

	if size.X < MIN_SIZE or size.Y < MIN_SIZE or size.Z < MIN_SIZE then
		return
	end

	part.Size = size -- expect: luau-shield002
end)
