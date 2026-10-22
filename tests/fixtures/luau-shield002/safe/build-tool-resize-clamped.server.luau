--!strict
-- Building game, fixed: a local helper clamps every component of the
-- requested size between MIN_SIZE and MAX_SIZE with math.clamp, and its
-- return value carries both bounds back to the handler. Clamping all three
-- components bounds the whole Vector3 (clamping only some would not).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResizePart = ReplicatedStorage.Remotes.Build.ResizePart :: RemoteEvent

local MIN_SIZE = 1
local MAX_SIZE = 32

local function clampSize(size: Vector3): Vector3
	return Vector3.new(
		math.clamp(size.X, MIN_SIZE, MAX_SIZE),
		math.clamp(size.Y, MIN_SIZE, MAX_SIZE),
		math.clamp(size.Z, MIN_SIZE, MAX_SIZE)
	)
end

ResizePart.OnServerEvent:Connect(function(player: Player, partId: string, size: Vector3)
	local plot = workspace.Plots:FindFirstChild(player.Name)
	local build = if plot then plot:FindFirstChild("Build") else nil
	local part = if build then build:FindFirstChild(partId) else nil
	if not part or not part:IsA("BasePart") or typeof(size) ~= "Vector3" then
		return
	end

	part.Size = clampSize(size)
end)
