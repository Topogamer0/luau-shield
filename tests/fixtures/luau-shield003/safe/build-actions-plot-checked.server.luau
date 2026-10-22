--!strict
-- Sandbox building, fixed: each handler takes the block out of the client
-- table and checks that it is inside the player's own plot
-- (workspace.Plots[player.Name]) before touching it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildRemotes = ReplicatedStorage.Remotes.Build

export type BuildRequest = {
	target: BasePart,
	color: Color3?,
}

local function getOwnedBlock(player: Player, data: BuildRequest): BasePart?
	if typeof(data) ~= "table" then
		return nil
	end
	local target = data.target
	local plot = workspace.Plots:FindFirstChild(player.Name)
	if not plot or typeof(target) ~= "Instance" or not target:IsDescendantOf(plot) then
		return nil
	end
	return if target:IsA("BasePart") then target else nil
end

local handlers: { [string]: (Player, BuildRequest) -> () } = {}

function handlers.RemoveBlock(player: Player, data: BuildRequest)
	local block = getOwnedBlock(player, data)
	if not block then
		return
	end
	block:Destroy()
end

function handlers.ColorBlock(player: Player, data: BuildRequest)
	local block = getOwnedBlock(player, data)
	local color = data.color
	if not block or typeof(color) ~= "Color3" then
		return
	end
	block.Color = color
end

for name, handler in handlers do
	local remote = BuildRemotes:WaitForChild(name) :: RemoteEvent
	remote.OnServerEvent:Connect(handler)
end
